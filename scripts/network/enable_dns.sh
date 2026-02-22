#!/usr/bin/env bash
set -euo pipefail

# Toggle: dnscrypt-proxy DoH + systemd-resolved + NetworkManager + UFW kill-switch
#
# IMPORTANT: this script DOES NOT write /etc/dnscrypt-proxy/dnscrypt-proxy.toml.
# You must configure it first. Minimal lines to set in the TOML:
#
#   listen_addresses = ['127.0.0.1:53', '[::1]:53']
#   dnscrypt_servers = false
#   doh_servers = true
#   require_dnssec = false
#   require_nolog = true
#   require_nofilter = true
#   server_names = ['cloudflare', 'quad9-doh']
#
# Then:
#   sudo systemctl enable --now dnscrypt-proxy
#   dig @127.0.0.1 google.com +short   # must work

STATE_DIR="/var/lib/dnscrypt-toggle"
STATE_FILE="${STATE_DIR}/enabled"
BACKUP_DIR="${STATE_DIR}/backup"

RESOLV_CONF="/etc/resolv.conf"
DNSCRYPT_TOML="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
RESOLVED_DROPIN_DIR="/etc/systemd/resolved.conf.d"
RESOLVED_DROPIN="${RESOLVED_DROPIN_DIR}/dnscrypt.conf"

ENABLE_UFW_KILLSWITCH="${ENABLE_UFW_KILLSWITCH:-1}"
DISABLE_DNSCRYPT_ON_DISABLE="${DISABLE_DNSCRYPT_ON_DISABLE:-1}"
RESTORE_UFW_ACTIVE_STATE="${RESTORE_UFW_ACTIVE_STATE:-1}"

need_cmd() { command -v "$1" >/dev/null 2>&1; }
as_root() { sudo "$@"; }
log() { printf '%s\n' "$*"; }

backup_path() {
  local p="$1"
  local b="${BACKUP_DIR}${p}"
  if [[ -e "$p" || -L "$p" ]]; then
    as_root mkdir -p "$(dirname "$b")"
    as_root cp -a "$p" "$b"
  fi
}

restore_path() {
  local p="$1"
  local b="${BACKUP_DIR}${p}"
  if [[ -e "$b" || -L "$b" ]]; then
    as_root rm -f "$p"
    as_root mkdir -p "$(dirname "$p")"
    as_root cp -a "$b" "$p"
  else
    as_root rm -f "$p" >/dev/null 2>&1 || true
  fi
}

ufw_is_active() {
  sudo ufw status 2>/dev/null | head -n1 | grep -q "Status: active"
}

ufw_add_rules() {
  if ! need_cmd ufw; then return 0; fi

  if ufw_is_active; then
    echo "active" | as_root tee "${STATE_DIR}/ufw_was_active" >/dev/null
  else
    echo "inactive" | as_root tee "${STATE_DIR}/ufw_was_active" >/dev/null
    as_root ufw --force enable >/dev/null
  fi

  # allow loopback out (so local stub/127.0.0.1 DNS still works)
  as_root ufw allow out on lo >/dev/null || true

  # block plaintext DNS + DoT
  as_root ufw deny out 53/udp >/dev/null || true
  as_root ufw deny out 53/tcp >/dev/null || true
  as_root ufw deny out 853/tcp >/dev/null || true

  as_root ufw reload >/dev/null || true
}

ufw_remove_rules() {
  if ! need_cmd ufw; then return 0; fi

  as_root ufw delete deny out 53/udp >/dev/null 2>&1 || true
  as_root ufw delete deny out 53/tcp >/dev/null 2>&1 || true
  as_root ufw delete deny out 853/tcp >/dev/null 2>&1 || true
  as_root ufw delete allow out on lo >/dev/null 2>&1 || true
  as_root ufw reload >/dev/null 2>&1 || true

  if [[ "$RESTORE_UFW_ACTIVE_STATE" == "1" ]] && [[ -f "${STATE_DIR}/ufw_was_active" ]]; then
    if grep -q "inactive" "${STATE_DIR}/ufw_was_active"; then
      as_root ufw --force disable >/dev/null 2>&1 || true
    fi
  fi
}

nm_get_active_conn() {
  nmcli -t -f NAME,DEVICE,TYPE connection show --active 2>/dev/null \
    | awk -F: '$3 ~ /^(ethernet|wifi)$/ { print $1; exit }'
}

nm_backup_conn_flags() {
  local conn="$1"
  as_root mkdir -p "$STATE_DIR"

  # store previous values (best effort)
  local v4 v6
  v4="$(nmcli -g ipv4.ignore-auto-dns connection show "$conn" 2>/dev/null || true)"
  v6="$(nmcli -g ipv6.ignore-auto-dns connection show "$conn" 2>/dev/null || true)"
  printf '%s\n' "$conn" | as_root tee "${STATE_DIR}/nm_conn" >/dev/null
  printf '%s\n' "$v4"   | as_root tee "${STATE_DIR}/nm_ipv4_ignore" >/dev/null
  printf '%s\n' "$v6"   | as_root tee "${STATE_DIR}/nm_ipv6_ignore" >/dev/null
}

nm_apply_ignore_dns() {
  local conn="$1"
  nmcli connection modify "$conn" ipv4.ignore-auto-dns yes >/dev/null
  nmcli connection modify "$conn" ipv6.ignore-auto-dns yes >/dev/null
  # bounce connection so settings take effect
  nmcli connection down "$conn" >/dev/null 2>&1 || true
  nmcli connection up "$conn" >/dev/null
}

nm_restore_conn_flags() {
  if ! need_cmd nmcli; then return 0; fi
  [[ -f "${STATE_DIR}/nm_conn" ]] || return 0

  local conn v4 v6
  conn="$(cat "${STATE_DIR}/nm_conn" 2>/dev/null || true)"
  v4="$(cat "${STATE_DIR}/nm_ipv4_ignore" 2>/dev/null || true)"
  v6="$(cat "${STATE_DIR}/nm_ipv6_ignore" 2>/dev/null || true)"
  [[ -n "$conn" ]] || return 0

  # If we don't know the previous value, default to "no"
  [[ -n "$v4" ]] || v4="no"
  [[ -n "$v6" ]] || v6="no"

  nmcli connection modify "$conn" ipv4.ignore-auto-dns "$v4" >/dev/null 2>&1 || true
  nmcli connection modify "$conn" ipv6.ignore-auto-dns "$v6" >/dev/null 2>&1 || true
  nmcli connection down "$conn" >/dev/null 2>&1 || true
  nmcli connection up "$conn" >/dev/null 2>&1 || true
}

dnscrypt_enable() {
  as_root systemctl enable --now dnscrypt-proxy
  as_root systemctl is-active --quiet dnscrypt-proxy
}

dnscrypt_disable() {
  as_root systemctl disable --now dnscrypt-proxy >/dev/null 2>&1 || true
}

wait_dnscrypt_ready() {
  # Prefer dig if available (most reliable). Otherwise fallback to getent after temporary resolvectl server pin.
  if need_cmd dig; then
    for _ in {1..80}; do
      if timeout 2 dig @127.0.0.1 google.com +short >/dev/null 2>&1; then
        return 0
      fi
      sleep 0.25
    done
    return 1
  fi

  # Fallback: try resolvectl query against 127.0.0.1
  if need_cmd resolvectl; then
    for _ in {1..80}; do
      if timeout 2 resolvectl query --legend=no --cache=no --no-pager --server=127.0.0.1 google.com >/dev/null 2>&1; then
        return 0
      fi
      sleep 0.25
    done
    return 1
  fi

  return 1
}

apply_resolved_dropin() {
  as_root mkdir -p "$RESOLVED_DROPIN_DIR"
  as_root tee "$RESOLVED_DROPIN" >/dev/null <<'EOF'
[Resolve]
DNS=127.0.0.1
FallbackDNS=
DNSStubListener=yes
LLMNR=no
MulticastDNS=no
EOF
  as_root systemctl restart systemd-resolved
  as_root ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
}

remove_resolved_dropin() {
  as_root rm -f "$RESOLVED_DROPIN" >/dev/null 2>&1 || true
  as_root systemctl restart systemd-resolved >/dev/null 2>&1 || true
}

dns_sanity() {
  timeout 4 getent hosts archlinux.org >/dev/null 2>&1
}

enable_mode() {
  log "Toggle: ENABLE (dnscrypt-proxy DoH + resolved + NM + UFW kill-switch)"

  as_root mkdir -p "$STATE_DIR" "$BACKUP_DIR"

  if [[ ! -f "$DNSCRYPT_TOML" ]]; then
    log "ERROR: missing $DNSCRYPT_TOML"
    log "Configure it first (see header comment in this script)."
    return 1
  fi

  log "[1] Backup /etc/resolv.conf and resolved drop-in..."
  backup_path "$RESOLV_CONF"
  backup_path "$RESOLVED_DROPIN"

  log "[2] Enable dnscrypt-proxy..."
  dnscrypt_enable

  log "[3] Wait dnscrypt-proxy ready on 127.0.0.1:53 (avoid bootstrap deadlock)..."
  if ! wait_dnscrypt_ready; then
    log "ERROR: dnscrypt-proxy did not become ready in time."
    as_root systemctl status dnscrypt-proxy --no-pager || true
    return 1
  fi

  log "[4] Force systemd-resolved to 127.0.0.1..."
  apply_resolved_dropin

  log "[5] NetworkManager: ignore DHCP DNS on active connection..."
  if need_cmd nmcli; then
    local conn
    conn="$(nm_get_active_conn || true)"
    if [[ -n "$conn" ]]; then
      nm_backup_conn_flags "$conn"
      nm_apply_ignore_dns "$conn"
    else
      log "WARN: no active ethernet/wifi NM connection detected (skipping)."
    fi
  else
    log "WARN: nmcli not found (skipping NetworkManager tweaks)."
  fi

  log "[6] Sanity check DNS (must pass)..."
  if ! dns_sanity; then
    log "ERROR: DNS sanity check failed."
    as_root systemctl status dnscrypt-proxy --no-pager || true
    return 1
  fi

  log "[7] Apply UFW plaintext-DNS kill-switch (optional)..."
  if [[ "$ENABLE_UFW_KILLSWITCH" == "1" ]]; then
    ufw_add_rules
  fi

  log "[8] Mark enabled..."
  as_root touch "$STATE_FILE"
  log "OK: enabled."
}

disable_mode() {
  log "Toggle: DISABLE (restore previous state)"

  log "[1] Remove UFW kill-switch rules (best effort)..."
  ufw_remove_rules

  log "[2] Restore NetworkManager DNS flags (best effort)..."
  nm_restore_conn_flags

  log "[3] Restore resolved drop-in + /etc/resolv.conf..."
  remove_resolved_dropin
  restore_path "$RESOLVED_DROPIN"
  restore_path "$RESOLV_CONF"
  as_root systemctl restart systemd-resolved >/dev/null 2>&1 || true

  log "[4] Optionally stop/disable dnscrypt-proxy..."
  if [[ "$DISABLE_DNSCRYPT_ON_DISABLE" == "1" ]]; then
    dnscrypt_disable
  fi

  log "[5] Cleanup state dir..."
  as_root rm -rf "$STATE_DIR" >/dev/null 2>&1 || true

  log "OK: disabled and restored."
}

main() {
  if [[ -f "$STATE_FILE" ]]; then
    disable_mode
    exit 0
  fi

  if ! enable_mode; then
    log "Rolling back..."
    disable_mode || true
    exit 1
  fi
}

main "$@"
