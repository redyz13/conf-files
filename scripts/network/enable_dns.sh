#!/usr/bin/env bash
set -euo pipefail

# Toggle: dnscrypt-proxy DoH + systemd-resolved + NetworkManager + UFW kill-switch
#
# Usage:
#   ./enable_dns.sh           # toggle: disabled -> enable, enabled -> disable
#   ./enable_dns.sh enable    # force enable/re-apply and install boot repair
#   ./enable_dns.sh disable   # restore original state and cleanup
#   ./enable_dns.sh repair    # repair enabled setup without disabling
#   ./enable_dns.sh status
#
# Boot behavior:
#   When enabled, this script installs:
#   - a NetworkManager dispatcher that repairs dnscrypt automatically after boot
#   - a WireGuard drop-in that makes wg-quick wait until local DNS is ready
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

STATE_DIR="/var/lib/dnscrypt-toggle"
STATE_FILE="${STATE_DIR}/enabled"
BACKUP_DIR="${STATE_DIR}/backup"

RESOLV_CONF="/etc/resolv.conf"
DNSCRYPT_TOML="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
RESOLVED_DROPIN_DIR="/etc/systemd/resolved.conf.d"
RESOLVED_DROPIN="${RESOLVED_DROPIN_DIR}/dnscrypt.conf"

SELF_INSTALL_PATH="/usr/local/sbin/dnscrypt-toggle"
BOOT_DISPATCHER="/etc/NetworkManager/dispatcher.d/45-dnscrypt-toggle-repair"

ENABLE_UFW_KILLSWITCH="${ENABLE_UFW_KILLSWITCH:-1}"
DISABLE_DNSCRYPT_ON_DISABLE="${DISABLE_DNSCRYPT_ON_DISABLE:-1}"
RESTORE_UFW_ACTIVE_STATE="${RESTORE_UFW_ACTIVE_STATE:-1}"

# WireGuard integration
INSTALL_WG_WAIT="${INSTALL_WG_WAIT:-1}"
WG_UNIT="${WG_UNIT:-wg-quick@wg0.service}"
WG_DROPIN_DIR="/etc/systemd/system/${WG_UNIT}.d"
WG_DROPIN="${WG_DROPIN_DIR}/10-wait-dnscrypt.conf"

# Campus DNS cleanup support
CAMPUS_DNS1="193.205.160.3"
CAMPUS_DNS2="193.205.160.139"

need_cmd() { command -v "$1" >/dev/null 2>&1; }

as_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

log() { printf '%s\n' "$*"; }

backup_path() {
  local p="$1"
  local b="${BACKUP_DIR}${p}"

  # Never overwrite the original backup once it exists.
  if [[ -e "$b" || -L "$b" ]]; then
    return 0
  fi

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
  as_root ufw status 2>/dev/null | head -n1 | grep -q "Status: active"
}

ufw_delete_killswitch_rules_only() {
  if ! need_cmd ufw; then return 0; fi

  as_root ufw delete deny out 53/udp >/dev/null 2>&1 || true
  as_root ufw delete deny out 53/tcp >/dev/null 2>&1 || true
  as_root ufw delete deny out 853/tcp >/dev/null 2>&1 || true
  as_root ufw delete allow out on lo >/dev/null 2>&1 || true

  as_root ufw reload >/dev/null 2>&1 || true
}

ufw_remove_campus_rules_best_effort() {
  if ! need_cmd ufw; then return 0; fi

  local ip dev
  local devices=()

  devices+=("wlp0s20f3")

  if need_cmd nmcli; then
    while IFS= read -r dev; do
      [[ -n "$dev" ]] && devices+=("$dev")
    done < <(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2=="wifi"{print $1}')
  fi

  for ip in "$CAMPUS_DNS1" "$CAMPUS_DNS2"; do
    as_root ufw delete allow out to "$ip" port 53 proto udp >/dev/null 2>&1 || true
    as_root ufw delete allow out to "$ip" port 53 proto tcp >/dev/null 2>&1 || true

    for dev in "${devices[@]}"; do
      as_root ufw delete allow out on "$dev" to "$ip" port 53 proto udp >/dev/null 2>&1 || true
      as_root ufw delete allow out on "$dev" to "$ip" port 53 proto tcp >/dev/null 2>&1 || true
    done
  done

  as_root ufw reload >/dev/null 2>&1 || true
}

ufw_record_original_state_once() {
  as_root mkdir -p "$STATE_DIR"

  if [[ -f "${STATE_DIR}/ufw_was_active" ]]; then
    return 0
  fi

  if ufw_is_active; then
    echo "active" | as_root tee "${STATE_DIR}/ufw_was_active" >/dev/null
  else
    echo "inactive" | as_root tee "${STATE_DIR}/ufw_was_active" >/dev/null
  fi
}

ufw_add_rules() {
  if ! need_cmd ufw; then return 0; fi

  ufw_record_original_state_once

  if ! ufw_is_active; then
    as_root ufw --force enable >/dev/null
  fi

  # Avoid duplicates if rules survived a reboot or a failed run.
  ufw_delete_killswitch_rules_only

  # Allow loopback out so local stub/127.0.0.1 DNS works.
  as_root ufw allow out on lo >/dev/null || true

  # Block plaintext DNS + DoT.
  as_root ufw deny out 53/udp >/dev/null || true
  as_root ufw deny out 53/tcp >/dev/null || true
  as_root ufw deny out 853/tcp >/dev/null || true

  as_root ufw reload >/dev/null || true
}

ufw_remove_rules() {
  if ! need_cmd ufw; then return 0; fi

  ufw_delete_killswitch_rules_only
  ufw_remove_campus_rules_best_effort

  if [[ "$RESTORE_UFW_ACTIVE_STATE" == "1" ]] && [[ -f "${STATE_DIR}/ufw_was_active" ]]; then
    if grep -q "inactive" "${STATE_DIR}/ufw_was_active"; then
      as_root ufw --force disable >/dev/null 2>&1 || true
    fi
  fi
}

wait_network_ready() {
  for _ in {1..80}; do
    if ip -4 route show default 2>/dev/null | grep -q '^default '; then
      return 0
    fi
    sleep 0.25
  done

  return 1
}

nm_get_active_conn() {
  if ! need_cmd nmcli; then return 0; fi

  local dev
  dev="$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null \
    | awk -F: '$3=="connected" && ($2=="wifi" || $2=="ethernet") { print $1; exit }')"

  [[ -n "${dev:-}" ]] || return 0

  nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null \
    | awk -F: -v d="$dev" '$2==d { print $1; exit }'
}

nm_device_for_conn() {
  local conn="$1"

  nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null \
    | awk -F: -v c="$conn" '$1==c { print $2; exit }'
}

nm_key_for_conn() {
  local conn="$1"
  printf '%s' "$conn" | sha256sum | awk '{print $1}'
}

nm_backup_conn_flags() {
  local conn="$1"
  local key dir
  key="$(nm_key_for_conn "$conn")"
  dir="${STATE_DIR}/nm"

  as_root mkdir -p "$dir"

  # Never overwrite original values for a connection.
  if [[ -f "${dir}/${key}.conn" ]]; then
    return 0
  fi

  local v4 v6
  v4="$(nmcli -g ipv4.ignore-auto-dns connection show "$conn" 2>/dev/null || true)"
  v6="$(nmcli -g ipv6.ignore-auto-dns connection show "$conn" 2>/dev/null || true)"

  {
    printf '%s\n' "$conn"
    printf '%s\n' "${v4:-no}"
    printf '%s\n' "${v6:-no}"
  } | as_root tee "${dir}/${key}.conn" >/dev/null
}

nm_apply_ignore_dns() {
  local conn="$1"
  local dev

  nmcli connection modify "$conn" ipv4.ignore-auto-dns yes >/dev/null
  nmcli connection modify "$conn" ipv6.ignore-auto-dns yes >/dev/null

  dev="$(nm_device_for_conn "$conn" || true)"
  if [[ -n "${dev:-}" ]]; then
    nmcli device reapply "$dev" >/dev/null 2>&1 || true
  fi
}

nm_restore_conn_flags() {
  if ! need_cmd nmcli; then return 0; fi

  local dir="${STATE_DIR}/nm"
  [[ -d "$dir" ]] || return 0

  local f conn v4 v6 dev

  for f in "$dir"/*.conn; do
    [[ -f "$f" ]] || continue

    conn="$(sed -n '1p' "$f" 2>/dev/null || true)"
    v4="$(sed -n '2p' "$f" 2>/dev/null || true)"
    v6="$(sed -n '3p' "$f" 2>/dev/null || true)"

    [[ -n "$conn" ]] || continue
    [[ -n "$v4" ]] || v4="no"
    [[ -n "$v6" ]] || v6="no"

    nmcli connection modify "$conn" ipv4.ignore-auto-dns "$v4" >/dev/null 2>&1 || true
    nmcli connection modify "$conn" ipv6.ignore-auto-dns "$v6" >/dev/null 2>&1 || true

    dev="$(nm_device_for_conn "$conn" || true)"
    if [[ -n "${dev:-}" ]]; then
      nmcli device reapply "$dev" >/dev/null 2>&1 || true
    fi
  done
}

apply_nm_ignore_dns_best_effort() {
  log "[NM] NetworkManager: ignore DHCP DNS on active connection..."

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
}

dnscrypt_enable() {
  as_root systemctl enable --now dnscrypt-proxy
  as_root systemctl is-active --quiet dnscrypt-proxy
}

dnscrypt_restart() {
  as_root systemctl enable dnscrypt-proxy >/dev/null 2>&1 || true
  as_root systemctl restart dnscrypt-proxy
  as_root systemctl is-active --quiet dnscrypt-proxy
}

dnscrypt_disable() {
  as_root systemctl disable --now dnscrypt-proxy >/dev/null 2>&1 || true
}

wait_dnscrypt_ready() {
  if need_cmd dig; then
    for _ in {1..120}; do
      if timeout 2 dig @127.0.0.1 google.com +short >/dev/null 2>&1; then
        return 0
      fi
      sleep 0.25
    done
    return 1
  fi

  if need_cmd resolvectl; then
    for _ in {1..120}; do
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
Domains=~.
DNSStubListener=yes
LLMNR=no
MulticastDNS=no
EOF

  as_root systemctl restart systemd-resolved
  as_root ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

  if need_cmd resolvectl; then
    resolvectl flush-caches >/dev/null 2>&1 || true
  fi
}

remove_resolved_dropin() {
  as_root rm -f "$RESOLVED_DROPIN" >/dev/null 2>&1 || true
  as_root systemctl restart systemd-resolved >/dev/null 2>&1 || true
}

dns_sanity() {
  timeout 4 getent hosts archlinux.org >/dev/null 2>&1
}

dns_via_local_ok() {
  # Strict check: test dnscrypt/local stub only.
  if need_cmd dig; then
    timeout 2 dig @127.0.0.1 archlinux.org +short >/dev/null 2>&1
    return $?
  fi

  if need_cmd resolvectl; then
    timeout 2 resolvectl query --legend=no --cache=no --no-pager --server=127.0.0.1 archlinux.org >/dev/null 2>&1
    return $?
  fi

  return 1
}

system_dns_ok() {
  # Normal system resolver check.
  timeout 3 getent hosts archlinux.org >/dev/null 2>&1
}

install_boot_repair_dispatcher() {
  local src
  src="$(readlink -f "$0")"

  log "[BOOT] Installing persistent helper: $SELF_INSTALL_PATH"
  if [[ "$src" != "$SELF_INSTALL_PATH" ]]; then
    as_root install -Dm755 "$src" "$SELF_INSTALL_PATH"
  else
    as_root chmod 755 "$SELF_INSTALL_PATH" >/dev/null 2>&1 || true
  fi

  log "[BOOT] Installing NetworkManager boot-repair dispatcher: $BOOT_DISPATCHER"
  as_root tee "$BOOT_DISPATCHER" >/dev/null <<EOF
#!/usr/bin/env bash
# Auto-repair dnscrypt-toggle after NetworkManager brings the network up.

set -euo pipefail

IFACE="\${1:-}"
STATUS="\${2:-}"

case "\$STATUS" in
  up|dhcp4-change|connectivity-change|vpn-up) ;;
  *) exit 0 ;;
esac

STATE_FILE="$STATE_FILE"
TOGGLE="$SELF_INSTALL_PATH"
TAG="dnscrypt-toggle-repair"
LOCK_FILE="/run/dnscrypt-toggle-repair.lock"

[[ -f "\$STATE_FILE" ]] || exit 0
[[ -x "\$TOGGLE" ]] || exit 0

exec 9>"\$LOCK_FILE"
flock -n 9 || exit 0

# Wait briefly for a default route.
for _ in {1..80}; do
  if ip -4 route show default 2>/dev/null | grep -q '^default '; then
    break
  fi
  sleep 0.25
done

# If local dnscrypt already works, do nothing.
if command -v dig >/dev/null 2>&1; then
  if timeout 2 dig @127.0.0.1 archlinux.org +short >/dev/null 2>&1; then
    exit 0
  fi
elif command -v resolvectl >/dev/null 2>&1; then
  if timeout 2 resolvectl query --legend=no --cache=no --no-pager --server=127.0.0.1 archlinux.org >/dev/null 2>&1; then
    exit 0
  fi
fi

logger -t "\$TAG" "DNS is broken after network up on \$IFACE; running repair"
"\$TOGGLE" repair >/dev/null 2>&1 || logger -t "\$TAG" "repair failed"
EOF

  as_root chmod 755 "$BOOT_DISPATCHER"
}

remove_boot_repair_dispatcher() {
  log "[BOOT] Removing boot-repair dispatcher and helper..."
  as_root rm -f "$BOOT_DISPATCHER" >/dev/null 2>&1 || true
  as_root rm -f "$SELF_INSTALL_PATH" >/dev/null 2>&1 || true
}

install_wireguard_wait_dns() {
  if [[ "$INSTALL_WG_WAIT" != "1" ]]; then
    log "[WG] WireGuard DNS wait disabled by INSTALL_WG_WAIT=0"
    return 0
  fi

  if ! systemctl list-unit-files "$WG_UNIT" >/dev/null 2>&1 && [[ ! -f "/etc/wireguard/wg0.conf" ]]; then
    log "[WG] WireGuard unit/config not found; skipping DNS wait drop-in."
    return 0
  fi

  log "[WG] Installing WireGuard DNS wait drop-in for $WG_UNIT"

  as_root mkdir -p "$WG_DROPIN_DIR"

  as_root tee "$WG_DROPIN" >/dev/null <<'EOF'
[Unit]
Wants=dnscrypt-proxy.service systemd-resolved.service network-online.target
After=dnscrypt-proxy.service systemd-resolved.service network-online.target

[Service]
ExecStartPre=/usr/bin/bash -c 'for i in {1..160}; do if command -v dig >/dev/null 2>&1; then timeout 2 dig @127.0.0.1 archlinux.org +short >/dev/null 2>&1 && exit 0; elif command -v resolvectl >/dev/null 2>&1; then timeout 2 resolvectl query --legend=no --cache=no --no-pager --server=127.0.0.1 archlinux.org >/dev/null 2>&1 && exit 0; fi; sleep 0.25; done; exit 1'
EOF

  as_root systemctl daemon-reload
  as_root systemctl reset-failed "$WG_UNIT" >/dev/null 2>&1 || true
}

remove_wireguard_wait_dns() {
  log "[WG] Removing WireGuard DNS wait drop-in..."

  as_root rm -f "$WG_DROPIN" >/dev/null 2>&1 || true
  as_root rmdir "$WG_DROPIN_DIR" >/dev/null 2>&1 || true
  as_root systemctl daemon-reload >/dev/null 2>&1 || true
  as_root systemctl reset-failed "$WG_UNIT" >/dev/null 2>&1 || true
}

enable_mode() {
  log "Toggle: ENABLE (dnscrypt-proxy DoH + resolved + NM + UFW kill-switch)"

  as_root mkdir -p "$STATE_DIR" "$BACKUP_DIR"

  if [[ ! -f "$DNSCRYPT_TOML" ]]; then
    log "ERROR: missing $DNSCRYPT_TOML"
    log "Configure it first (see header comment in this script)."
    return 1
  fi

  if [[ ! -f "$STATE_FILE" ]]; then
    log "[1] Backup /etc/resolv.conf and resolved drop-in..."
    backup_path "$RESOLV_CONF"
    backup_path "$RESOLVED_DROPIN"
  else
    log "[1] Already enabled: keeping existing backups."
  fi

  log "[2] Temporarily remove UFW kill-switch rules for bootstrap..."
  ufw_delete_killswitch_rules_only

  log "[3] Wait network ready..."
  if ! wait_network_ready; then
    log "WARN: no default route detected yet; continuing anyway."
  fi

  log "[4] Enable dnscrypt-proxy..."
  dnscrypt_enable

  log "[5] Wait dnscrypt-proxy ready on 127.0.0.1:53..."
  if ! wait_dnscrypt_ready; then
    log "ERROR: dnscrypt-proxy did not become ready in time."
    as_root systemctl status dnscrypt-proxy --no-pager || true
    return 1
  fi

  log "[6] Force systemd-resolved to 127.0.0.1..."
  apply_resolved_dropin

  log "[7] Apply NetworkManager DNS settings..."
  apply_nm_ignore_dns_best_effort

  log "[8] Sanity check DNS..."
  if ! dns_sanity; then
    log "ERROR: DNS sanity check failed."
    as_root systemctl status dnscrypt-proxy --no-pager || true
    return 1
  fi

  log "[9] Apply UFW plaintext-DNS kill-switch..."
  if [[ "$ENABLE_UFW_KILLSWITCH" == "1" ]]; then
    ufw_add_rules
  fi

  log "[10] Install boot auto-repair..."
  install_boot_repair_dispatcher

  log "[11] Install WireGuard DNS wait..."
  install_wireguard_wait_dns

  log "[12] Mark enabled..."
  as_root touch "$STATE_FILE"

  log "OK: enabled."
}

repair_mode() {
  log "Toggle: REPAIR (keep enabled, fix DNS after boot if needed)"

  as_root mkdir -p "$STATE_DIR" "$BACKUP_DIR"

  if [[ ! -f "$DNSCRYPT_TOML" ]]; then
    log "ERROR: missing $DNSCRYPT_TOML"
    return 1
  fi

  log "[1] Wait network ready..."
  if ! wait_network_ready; then
    log "WARN: no default route detected yet; continuing anyway."
  fi

  log "[2] Try restarting dnscrypt-proxy with kill-switch still active..."
  dnscrypt_restart || true

  if wait_dnscrypt_ready; then
    log "[3] dnscrypt-proxy is ready without opening the kill-switch."
  else
    log "[3] dnscrypt-proxy is not ready; temporarily opening kill-switch for bootstrap..."
    ufw_delete_killswitch_rules_only

    log "[4] Restart dnscrypt-proxy after temporary bootstrap opening..."
    dnscrypt_restart

    log "[5] Wait dnscrypt-proxy ready on 127.0.0.1:53..."
    if ! wait_dnscrypt_ready; then
      log "ERROR: dnscrypt-proxy did not become ready in time."
      as_root systemctl status dnscrypt-proxy --no-pager || true
      return 1
    fi

    log "[6] Re-apply UFW plaintext-DNS kill-switch immediately..."
    if [[ "$ENABLE_UFW_KILLSWITCH" == "1" ]]; then
      ufw_add_rules
    fi
  fi

  log "[7] Re-apply systemd-resolved configuration..."
  apply_resolved_dropin

  log "[8] Re-apply NetworkManager DNS settings..."
  apply_nm_ignore_dns_best_effort

  log "[9] Sanity check DNS..."
  if ! dns_sanity; then
    log "ERROR: DNS sanity check failed."
    as_root systemctl status dnscrypt-proxy --no-pager || true
    return 1
  fi

  log "[10] Ensure UFW plaintext-DNS kill-switch is active..."
  if [[ "$ENABLE_UFW_KILLSWITCH" == "1" ]]; then
    ufw_add_rules
  fi

  log "[11] Ensure boot auto-repair is installed..."
  install_boot_repair_dispatcher

  log "[12] Ensure WireGuard DNS wait is installed..."
  install_wireguard_wait_dns

  log "[13] Mark enabled..."
  as_root touch "$STATE_FILE"

  log "OK: repaired and enabled."
}

disable_mode() {
  log "Toggle: DISABLE (restore previous state)"

  log "[1] Remove UFW kill-switch and campus allow rules (best effort)..."
  ufw_remove_rules

  log "[2] Restore NetworkManager DNS flags (best effort)..."
  nm_restore_conn_flags

  log "[3] Restore resolved drop-in + /etc/resolv.conf..."
  remove_resolved_dropin
  restore_path "$RESOLVED_DROPIN"
  restore_path "$RESOLV_CONF"
  as_root systemctl restart systemd-resolved >/dev/null 2>&1 || true

  log "[4] Remove boot auto-repair..."
  remove_boot_repair_dispatcher

  log "[5] Remove WireGuard DNS wait..."
  remove_wireguard_wait_dns

  log "[6] Optionally stop/disable dnscrypt-proxy..."
  if [[ "$DISABLE_DNSCRYPT_ON_DISABLE" == "1" ]]; then
    dnscrypt_disable
  fi

  log "[7] Cleanup state dir..."
  as_root rm -rf "$STATE_DIR" >/dev/null 2>&1 || true

  log "OK: disabled and restored."
}

status_mode() {
  log "State file: $([[ -f "$STATE_FILE" ]] && echo enabled || echo disabled)"

  if systemctl is-active --quiet dnscrypt-proxy; then
    log "dnscrypt-proxy: active"
  else
    log "dnscrypt-proxy: inactive/not-ready"
  fi

  if [[ -x "$BOOT_DISPATCHER" ]]; then
    log "boot repair dispatcher: installed"
  else
    log "boot repair dispatcher: not installed"
  fi

  if [[ -f "$WG_DROPIN" ]]; then
    log "WireGuard DNS wait: installed ($WG_UNIT)"
  else
    log "WireGuard DNS wait: not installed"
  fi

  if dns_via_local_ok; then
    log "DNS via 127.0.0.1: OK"
  else
    log "DNS via 127.0.0.1: not available"
  fi

  if system_dns_ok; then
    log "System DNS: OK"
  else
    log "System DNS: BROKEN"
  fi

  if need_cmd ufw; then
    as_root ufw status | sed -n '1,30p'
  fi
}

rollback_after_failure() {
  log "Rolling back..."
  disable_mode || true
}

main() {
  local action="${1:-toggle}"

  case "$action" in
    enable)
      if ! enable_mode; then
        rollback_after_failure
        exit 1
      fi
      ;;

    disable)
      disable_mode
      ;;

    repair)
      if ! repair_mode; then
        rollback_after_failure
        exit 1
      fi
      ;;

    status)
      status_mode
      ;;

    toggle)
      if [[ -f "$STATE_FILE" ]]; then
        disable_mode
      else
        if ! enable_mode; then
          rollback_after_failure
          exit 1
        fi
      fi
      ;;

    *)
      log "Usage: $0 [enable|disable|repair|status]"
      exit 2
      ;;
  esac
}

main "$@"
