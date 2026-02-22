#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="/var/lib/warp-dns-toggle"
STATE_FILE="${STATE_DIR}/enabled"
BACKUP_DIR="${STATE_DIR}/backup"

RESOLV_CONF="/etc/resolv.conf"
UNIT="warp-svc.service"

ENABLE_UFW_KILLSWITCH="${ENABLE_UFW_KILLSWITCH:-1}"
DISABLE_WARP_SERVICE_ON_DISABLE="${DISABLE_WARP_SERVICE_ON_DISABLE:-1}"
RESTORE_UFW_ACTIVE_STATE="${RESTORE_UFW_ACTIVE_STATE:-1}"

need_cmd() { command -v "$1" >/dev/null 2>&1; }
as_root() { sudo "$@"; }
log() { printf '%s\n' "$*"; }

warp() { sudo warp-cli "$@"; }

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
  if ufw_is_active; then
    echo "active" | as_root tee "${STATE_DIR}/ufw_was_active" >/dev/null
  else
    echo "inactive" | as_root tee "${STATE_DIR}/ufw_was_active" >/dev/null
    as_root ufw --force enable >/dev/null
  fi

  as_root ufw allow out on lo >/dev/null || true
  as_root ufw deny out 53/udp >/dev/null || true
  as_root ufw deny out 53/tcp >/dev/null || true
  as_root ufw reload >/dev/null || true
}

ufw_remove_rules() {
  if ! need_cmd ufw; then return 0; fi

  as_root ufw delete deny out 53/udp >/dev/null 2>&1 || true
  as_root ufw delete deny out 53/tcp >/dev/null 2>&1 || true
  as_root ufw delete allow out on lo >/dev/null 2>&1 || true
  as_root ufw reload >/dev/null 2>&1 || true

  if [[ "$RESTORE_UFW_ACTIVE_STATE" == "1" ]] && [[ -f "${STATE_DIR}/ufw_was_active" ]]; then
    if grep -q "inactive" "${STATE_DIR}/ufw_was_active"; then
      as_root ufw --force disable >/dev/null 2>&1 || true
    fi
  fi
}

warp_service_enable() {
  as_root systemctl enable --now "$UNIT"
  as_root systemctl is-active --quiet "$UNIT"
}

warp_service_disable() {
  as_root systemctl disable --now "$UNIT" >/dev/null 2>&1 || true
}

warp_daemon_ready() {
  # Wait until warp-cli can talk to warp-svc
  for _ in {1..80}; do
    if warp status >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done
  return 1
}

warp_connected() {
  # Accept both formats:
  # - "Status: Connected"
  # - "Status update: Connected"
  for _ in {1..120}; do
    if warp status 2>/dev/null | grep -qiE '^Status(:| update:) Connected'; then
      return 0
    fi
    sleep 0.25
  done
  return 1
}

dns_sanity() {
  timeout 4 getent hosts archlinux.org >/dev/null 2>&1
}

enable_mode() {
  log "Toggle: ENABLE"
  as_root mkdir -p "$STATE_DIR" "$BACKUP_DIR"

  if ! need_cmd warp-cli; then
    log "ERROR: warp-cli not found."
    log "Install cloudflare-warp(-bin) first."
    return 1
  fi

  log "[1/9] Backup /etc/resolv.conf..."
  backup_path "$RESOLV_CONF"

  log "[2/9] Start WARP daemon (${UNIT})..."
  warp_service_enable

  log "[3/9] Wait for daemon IPC..."
  if ! warp_daemon_ready; then
    log "ERROR: warp-cli cannot reach the daemon."
    as_root systemctl status "$UNIT" --no-pager || true
    return 1
  fi

  log "[4/9] Ensure registration exists..."
  if ! warp registration show >/dev/null 2>&1; then
    log "ERROR: WARP is not registered yet (first run)."
    log "Run once (interactive) and accept ToS:"
    log "  sudo warp-cli registration new"
    return 1
  fi

  log "[5/9] Set DNS-only mode (DoH)..."
  warp mode doh >/dev/null

  log "[6/9] Connect..."
  warp connect >/dev/null

  log "[7/9] Pre-firewall tests (must pass)..."
  if ! warp_connected; then
    log "ERROR: WARP did not reach Connected state."
    warp status || true
    return 1
  fi

  if ! dns_sanity; then
    log "ERROR: DNS sanity check failed."
    warp status || true
    return 1
  fi

  log "[8/9] Apply UFW plaintext-DNS kill-switch (optional)..."
  if [[ "$ENABLE_UFW_KILLSWITCH" == "1" ]] && need_cmd ufw; then
    ufw_add_rules
  fi

  log "[9/9] Mark enabled..."
  as_root touch "$STATE_FILE"

  # Final confirm (avoid transient "Status update" noise)
  if warp_connected; then
    warp status || true
    log "OK: enabled."
  else
    log "WARN: enabled, but status is not stable yet. Re-check with: sudo warp-cli status"
    log "OK: enabled."
  fi
}

disable_mode() {
  log "Toggle: DISABLE"

  log "[1/8] Remove UFW kill-switch rules (best effort)..."
  ufw_remove_rules

  log "[2/8] Disconnect WARP (best effort)..."
  warp disconnect >/dev/null 2>&1 || true

  log "[3/8] Restore /etc/resolv.conf..."
  restore_path "$RESOLV_CONF"

  log "[4/8] Optionally delete registration created by this script..."
  # Keep registration by default: deleting it is "more state-0" but annoying to redo ToS.
  # Enable only if you explicitly want it:
  #   export DELETE_WARP_REG_ON_DISABLE=1
  if [[ "${DELETE_WARP_REG_ON_DISABLE:-0}" == "1" ]]; then
    warp registration delete >/dev/null 2>&1 || true
  fi

  log "[5/8] Optionally stop/disable WARP service..."
  if [[ "$DISABLE_WARP_SERVICE_ON_DISABLE" == "1" ]]; then
    warp_service_disable
  fi

  log "[6/8] Restart NetworkManager (best effort)..."
  as_root systemctl restart NetworkManager >/dev/null 2>&1 || true

  log "[7/8] Remove toggle state directory..."
  as_root rm -rf "$STATE_DIR" >/dev/null 2>&1 || true

  log "[8/8] Done."
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
