#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
ROOT_DIR="${TEST_DIR}/root"
MOCK_BIN="${TEST_DIR}/bin"
MOCK_STATE="${TEST_DIR}/mock-state"
TEST_MANAGER="${TEST_DIR}/dnscrypt-toggle"
TEST_FIREWALL="${TEST_DIR}/dnscrypt-toggle-firewall"

grep -Fxq 'RuntimeDirectory=dnscrypt-toggle-firewall' \
  "$PROJECT_DIR/dnscrypt-toggle-killswitch.service"
grep -Fq 'mktemp --tmpdir="$RUNTIME_DIR"' \
  "$PROJECT_DIR/dnscrypt-toggle-firewall"
! grep -Fq 'wg-quick@wg0.service' \
  "$PROJECT_DIR/dnscrypt-toggle-reconcile.service"
grep -Fq 'After=dnscrypt-toggle-reconcile.service' \
  "$PROJECT_DIR/dnscrypt-toggle"
grep -Fq 'ExecStartPre=/usr/local/sbin/dnscrypt-toggle wg-ready %i' \
  "$PROJECT_DIR/dnscrypt-toggle"
grep -Fq 'Restart=on-failure' \
  "$PROJECT_DIR/dnscrypt-toggle"
! grep -Fq 'campus_dns' "$PROJECT_DIR/dnscrypt-toggle-firewall"
grep -Fq 'readonly LOCK_TARGET="${BASH_SOURCE[0]}"' \
  "$PROJECT_DIR/dnscrypt-toggle"
! grep -Fq 'exec 9>"$LOCK_FILE"' \
  "$PROJECT_DIR/dnscrypt-toggle"
bash -n "$PROJECT_DIR/install-live.sh" "$PROJECT_DIR/uninstall-live.sh"

cleanup() {
  if [[ "${KEEP_TEST_DIR:-0}" == "1" ]]; then
    printf 'kept test directory: %s\n' "$TEST_DIR" >&2
  else
    rm -rf -- "$TEST_DIR"
  fi
}
trap cleanup EXIT

mkdir -p \
  "$ROOT_DIR/etc/dnscrypt-proxy" \
  "$ROOT_DIR/etc/systemd/resolved.conf.d" \
  "$ROOT_DIR/etc/NetworkManager/conf.d" \
  "$ROOT_DIR/etc/NetworkManager/dispatcher.d" \
  "$ROOT_DIR/etc/systemd/system" \
  "$ROOT_DIR/etc/systemd/system/NetworkManager.service.d" \
  "$ROOT_DIR/etc/systemd/system/wg-quick@wg0.service.d" \
  "$ROOT_DIR/etc/wireguard" \
  "$ROOT_DIR/run/systemd/resolve" \
  "$ROOT_DIR/run/lock" \
  "$ROOT_DIR/run/dnscrypt-toggle-firewall" \
  "$ROOT_DIR/usr/local/libexec" \
  "$MOCK_BIN" "$MOCK_STATE"

printf 'original toml\n' >"$ROOT_DIR/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
printf 'original resolved\n' >"$ROOT_DIR/etc/systemd/resolved.conf.d/dnscrypt.conf"
printf 'original nm\n' >"$ROOT_DIR/etc/NetworkManager/conf.d/99-dnscrypt-toggle.conf"
printf 'nameserver original\n' >"$ROOT_DIR/etc/resolv.original"
ln -s "$ROOT_DIR/etc/resolv.original" "$ROOT_DIR/etc/resolv.conf"
printf '[Unit]\n' >"$ROOT_DIR/etc/systemd/system/dnscrypt-toggle-killswitch.service"
printf '[Unit]\n' >"$ROOT_DIR/etc/systemd/system/dnscrypt-toggle-reconcile.service"
printf '#!/usr/bin/env bash\n# original dispatcher\n' >"$ROOT_DIR/etc/NetworkManager/dispatcher.d/50-dnscrypt-campus"
chmod +x "$ROOT_DIR/etc/NetworkManager/dispatcher.d/50-dnscrypt-campus"
printf '[Unit]\n# original WireGuard readiness guard\n' >"$ROOT_DIR/etc/systemd/system/wg-quick@wg0.service.d/10-wait-dns.conf"
printf '[Peer]\nEndpoint = endpoint.test:51820\n' >"$ROOT_DIR/etc/wireguard/wg0.conf"
install -m 0755 "$PROJECT_DIR/90-dnscrypt-toggle" "$ROOT_DIR/usr/local/libexec/dnscrypt-toggle-dispatcher"

for unit_state in \
  'dnscrypt-proxy.service disabled inactive' \
  'systemd-resolved.service enabled active' \
  'dnscrypt-toggle-killswitch.service disabled inactive' \
  'dnscrypt-toggle-reconcile.service disabled inactive' \
  'nftables.service disabled inactive'; do
  read -r unit enabled active <<<"$unit_state"
  printf '%s\n' "$enabled" >"$MOCK_STATE/$unit.enabled"
  printf '%s\n' "$active" >"$MOCK_STATE/$unit.active"
done

printf 'normal\n' >"$MOCK_STATE/network"
printf 'absent\n' >"$MOCK_STATE/nft-table"
printf 'stale\n' >"$MOCK_STATE/link-dns"
: >"$MOCK_STATE/nmcli-log"
: >"$MOCK_STATE/systemctl-log"
: >"$MOCK_STATE/resolvectl-log"
: >"$MOCK_STATE/ufw-untouched"

sed \
  -e "s|readonly SAFE_PATH=\"/usr/local/sbin:/usr/local/bin:/usr/bin\"|readonly SAFE_PATH=\"$MOCK_BIN:/usr/bin\"|" \
  -e "s|readonly NFT_BIN=\"/usr/bin/nft\"|readonly NFT_BIN=\"$MOCK_BIN/nft\"|" \
  -e "s|readonly RUNTIME_DIR=\"/run/dnscrypt-toggle-firewall\"|readonly RUNTIME_DIR=\"$ROOT_DIR/run/dnscrypt-toggle-firewall\"|" \
  -e 's~(( EUID == 0 )) || die "must run as root"~: # Privilege check disabled in isolated mock.~' \
  -e "s|mktemp --tmpdir=/run |mktemp --tmpdir=$ROOT_DIR/run |g" \
  "$PROJECT_DIR/dnscrypt-toggle-firewall" >"$TEST_FIREWALL"
chmod +x "$TEST_FIREWALL"

sed \
  -e "s|readonly SAFE_PATH=\"/usr/local/sbin:/usr/local/bin:/usr/bin\"|readonly SAFE_PATH=\"$MOCK_BIN:/usr/bin\"|" \
  -e 's|if (( EUID != 0 )); then|if (( 0 )); then|' \
  -e 's| -o root -g root||g' \
  -e "s|readonly STATE_DIR=\"/var/lib/dnscrypt-toggle\"|readonly STATE_DIR=\"$ROOT_DIR/var/lib/dnscrypt-toggle\"|" \
  -e "s|readonly GUARD_MARKER=\"/etc/dnscrypt-toggle-enabled\"|readonly GUARD_MARKER=\"$ROOT_DIR/etc/dnscrypt-toggle-enabled\"|" \
  -e "s|readonly DNSCRYPT_TOML=\"/etc/dnscrypt-proxy/dnscrypt-proxy.toml\"|readonly DNSCRYPT_TOML=\"$ROOT_DIR/etc/dnscrypt-proxy/dnscrypt-proxy.toml\"|" \
  -e "s|readonly RESOLV_CONF=\"/etc/resolv.conf\"|readonly RESOLV_CONF=\"$ROOT_DIR/etc/resolv.conf\"|" \
  -e "s|readonly RESOLVED_DROPIN=\"/etc/systemd/resolved.conf.d/dnscrypt.conf\"|readonly RESOLVED_DROPIN=\"$ROOT_DIR/etc/systemd/resolved.conf.d/dnscrypt.conf\"|" \
  -e "s|readonly NM_DROPIN=\"/etc/NetworkManager/conf.d/99-dnscrypt-toggle.conf\"|readonly NM_DROPIN=\"$ROOT_DIR/etc/NetworkManager/conf.d/99-dnscrypt-toggle.conf\"|" \
  -e "s|readonly FIREWALL_HELPER=\"/usr/local/libexec/dnscrypt-toggle-firewall\"|readonly FIREWALL_HELPER=\"$TEST_FIREWALL\"|" \
  -e "s|readonly DISPATCHER_SOURCE=\"/usr/local/libexec/dnscrypt-toggle-dispatcher\"|readonly DISPATCHER_SOURCE=\"$ROOT_DIR/usr/local/libexec/dnscrypt-toggle-dispatcher\"|" \
  -e "s|readonly KILLSWITCH_UNIT_PATH=\"/etc/systemd/system/\${KILLSWITCH_UNIT}\"|readonly KILLSWITCH_UNIT_PATH=\"$ROOT_DIR/etc/systemd/system/\${KILLSWITCH_UNIT}\"|" \
  -e "s|readonly RECONCILE_UNIT_PATH=\"/etc/systemd/system/\${RECONCILE_UNIT}\"|readonly RECONCILE_UNIT_PATH=\"$ROOT_DIR/etc/systemd/system/\${RECONCILE_UNIT}\"|" \
  -e "s|readonly LEGACY_DISPATCHER_PATH=\"/etc/NetworkManager/dispatcher.d/50-dnscrypt-campus\"|readonly LEGACY_DISPATCHER_PATH=\"$ROOT_DIR/etc/NetworkManager/dispatcher.d/50-dnscrypt-campus\"|" \
  -e "s|readonly DISPATCHER_PATH=\"/etc/NetworkManager/dispatcher.d/90-dnscrypt-toggle\"|readonly DISPATCHER_PATH=\"$ROOT_DIR/etc/NetworkManager/dispatcher.d/90-dnscrypt-toggle\"|" \
  -e "s|readonly NM_UNIT_DROPIN=\"/etc/systemd/system/NetworkManager.service.d/50-dnscrypt-toggle-killswitch.conf\"|readonly NM_UNIT_DROPIN=\"$ROOT_DIR/etc/systemd/system/NetworkManager.service.d/50-dnscrypt-toggle-killswitch.conf\"|" \
  -e "s|readonly WG_CONFIG_DIR=\"/etc/wireguard\"|readonly WG_CONFIG_DIR=\"$ROOT_DIR/etc/wireguard\"|" \
  -e "s|readonly WG_UNIT_DROPIN=\"/etc/systemd/system/wg-quick@\${WG_INTERFACE}.service.d/20-dnscrypt-toggle.conf\"|readonly WG_UNIT_DROPIN=\"$ROOT_DIR/etc/systemd/system/wg-quick@\${WG_INTERFACE}.service.d/20-dnscrypt-toggle.conf\"|" \
  -e 's|readonly WG_DNS_ATTEMPTS=24|readonly WG_DNS_ATTEMPTS=2|' \
  -e 's|readonly WG_DNS_RETRY_DELAY=0.5|readonly WG_DNS_RETRY_DELAY=0.01|' \
  -e 's|readonly DNSCRYPT_READY_ATTEMPTS=60|readonly DNSCRYPT_READY_ATTEMPTS=2|' \
  -e 's|readonly DNSCRYPT_READY_DELAY=0.5|readonly DNSCRYPT_READY_DELAY=0.01|' \
  -e "s|readonly LEGACY_MANAGER_LOCK_FILE=\"/run/lock/dnscrypt-toggle.lock\"|readonly LEGACY_MANAGER_LOCK_FILE=\"$ROOT_DIR/run/lock/dnscrypt-toggle.lock\"|" \
  -e "s|readonly FIREWALL_RUNTIME_DIR=\"/run/dnscrypt-toggle-firewall\"|readonly FIREWALL_RUNTIME_DIR=\"$ROOT_DIR/run/dnscrypt-toggle-firewall\"|" \
  -e "s|readonly LEGACY_FIREWALL_LOCK_FILE=\"/run/lock/dnscrypt-toggle-firewall.lock\"|readonly LEGACY_FIREWALL_LOCK_FILE=\"$ROOT_DIR/run/lock/dnscrypt-toggle-firewall.lock\"|" \
  -e "s|mktemp --tmpdir=/run |mktemp --tmpdir=$ROOT_DIR/run |g" \
  -e "s|/run/systemd/resolve/stub-resolv.conf|$ROOT_DIR/run/systemd/resolve/stub-resolv.conf|g" \
  "$PROJECT_DIR/dnscrypt-toggle" >"$TEST_MANAGER"
chmod +x "$TEST_MANAGER"

cat >"$MOCK_BIN/nft" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

state="${MOCK_STATE:?}"
table_file="$state/nft-table"

if [[ "${1:-}" == "--check" && "${2:-}" == "--file" ]]; then
  [[ ! -f "$state/fail-nft-check" ]]
  exit
fi

if [[ "${1:-}" == "--file" ]]; then
  input="$2"
  if grep -Fq 'table inet dnscrypt_toggle' "$input"; then
    printf 'present\n' >"$table_file"
  fi
  exit
fi

if [[ "$*" == 'list table inet dnscrypt_toggle' ]]; then
  [[ "$(cat "$table_file")" == present ]] || exit 1
  cat <<RULES
table inet dnscrypt_toggle {
  chain output {
    type filter hook output priority mangle; policy accept;
    comment "dnscrypt-toggle:loopback"
    comment "dnscrypt-toggle:dns-dot-doq-udp"
    comment "dnscrypt-toggle:dns-dot-tcp"
$(if [[ -f "$state/nft-extra-rule" ]]; then printf '    udp dport 53 accept\n'; fi)
  }
}
RULES
  exit
fi

if [[ "$*" == 'delete table inet dnscrypt_toggle' ]]; then
  [[ ! -f "$state/fail-nft-delete" ]] || exit 1
  printf 'absent\n' >"$table_file"
  exit
fi

printf 'unexpected nft command: %s\n' "$*" >&2
exit 1
EOF

cat >"$MOCK_BIN/systemctl" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

state="${MOCK_STATE:?}"
command_name="$1"
shift
printf '%s %s\n' "$command_name" "$*" >>"$state/systemctl-log"
quiet=0
runtime=0

while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --quiet) quiet=1 ;;
    --runtime) runtime=1 ;;
  esac
  shift
done

case "$command_name" in
  daemon-reload) exit 0 ;;
  # Match systemd's live behaviour for a oneshot that was enabled but never
  # loaded: cleanup must not fail merely because reset-failed returns nonzero.
  reset-failed) exit 1 ;;
  is-enabled)
    unit="$1"
    value="$(cat "$state/$unit.enabled")"
    (( quiet == 1 )) || printf '%s\n' "$value"
    [[ "$value" == enabled || "$value" == enabled-runtime ]]
    ;;
  is-active)
    unit="$1"
    value="$(cat "$state/$unit.active")"
    (( quiet == 1 )) || printf '%s\n' "$value"
    [[ "$value" == active ]]
    ;;
  enable|disable)
    value=disabled
    [[ "$command_name" == enable ]] && value=enabled
    (( runtime == 1 )) && value=enabled-runtime
    for unit in "$@"; do
      if [[ "$command_name" == disable && "$unit" == dnscrypt-proxy.service && -f "$state/fail-disable-dnscrypt" ]]; then
        exit 1
      fi
      printf '%s\n' "$value" >"$state/$unit.enabled"
    done
    ;;
  start|restart)
    for unit in "$@"; do
      printf 'active\n' >"$state/$unit.active"
      if [[ "$unit" == dnscrypt-toggle-killswitch.service ]]; then
        "${MOCK_FIREWALL_HELPER:?}" load
      fi
    done
    ;;
  stop)
    for unit in "$@"; do
      printf 'inactive\n' >"$state/$unit.active"
      if [[ "$unit" == dnscrypt-toggle-killswitch.service ]]; then
        "${MOCK_FIREWALL_HELPER:?}" unload
      fi
    done
    ;;
  *) printf 'unexpected systemctl command: %s %s\n' "$command_name" "$*" >&2; exit 1 ;;
esac
EOF

cat >"$MOCK_BIN/nmcli" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >>"${MOCK_STATE:?}/nmcli-log"
case "$*" in
  'general reload conf') exit 0 ;;
  'general reload dns-full') printf 'stale\n' >"$MOCK_STATE/link-dns" ;;
  '-t -f DEVICE connection show --active') printf 'wlan0\nwg0\nlo\n' ;;
  *) printf 'unexpected nmcli command: %s\n' "$*" >&2; exit 1 ;;
esac
EOF

cat >"$MOCK_BIN/ip" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
case "$*" in
  '-6 route show default') exit 0 ;;
  *) exit 0 ;;
esac
EOF

cat >"$MOCK_BIN/resolvectl" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
state="${MOCK_STATE:?}"
printf '%s\n' "$*" >>"$state/resolvectl-log"
case "$*" in
  dns)
    printf 'Global: 127.0.0.1\n'
    if [[ "$(cat "$state/link-dns")" == stale ]]; then
      printf 'Link 2 (wlan0): 192.168.1.1 1.1.1.1 1.0.0.1\n'
    else
      printf 'Link 2 (wlan0):\n'
    fi
    ;;
  'revert wlan0') printf 'clean\n' >"$state/link-dns" ;;
  'query --cache=no --legend=no --no-pager endpoint.test')
    [[ ! -f "$state/fail-wg-dns" ]]
    ;;
  *) exit 0 ;;
esac
EOF

cat >"$MOCK_BIN/dig" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
case "$*" in
  '@127.0.0.1 '*) printf '93.184.216.34\n' ;;
  '@9.9.9.9 '*) exit 1 ;;
  *) exit 1 ;;
esac
EOF

cat >"$MOCK_BIN/dnscrypt-proxy" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ ! -f "${MOCK_STATE:?}/fail-dnscrypt" ]]
EOF

cat >"$MOCK_BIN/getent" <<'EOF'
#!/usr/bin/env bash
[[ ! -f "${MOCK_STATE:?}/fail-system-dns" ]]
EOF

cat >"$MOCK_BIN/logger" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat >"$MOCK_BIN/systemd-analyze" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == 'verify wg-quick@wg0.service' ]]
EOF

chmod +x "$MOCK_BIN"/*

export MOCK_STATE
export MOCK_FIREWALL_HELPER="$TEST_FIREWALL"
export PATH="$MOCK_BIN:$PATH"

assert_eq() {
  [[ "$1" == "$2" ]] || {
    printf 'assertion failed: <%s> != <%s>\n' "$1" "$2" >&2
    exit 1
  }
}

assert_clean_restore() {
  [[ ! -e "$ROOT_DIR/var/lib/dnscrypt-toggle" ]]
  [[ ! -e "$ROOT_DIR/etc/dnscrypt-toggle-enabled" ]]
  assert_eq "$(cat "$ROOT_DIR/etc/dnscrypt-proxy/dnscrypt-proxy.toml")" 'original toml'
  assert_eq "$(cat "$ROOT_DIR/etc/systemd/resolved.conf.d/dnscrypt.conf")" 'original resolved'
  assert_eq "$(cat "$ROOT_DIR/etc/NetworkManager/conf.d/99-dnscrypt-toggle.conf")" 'original nm'
  [[ ! -e "$ROOT_DIR/etc/systemd/system/NetworkManager.service.d/50-dnscrypt-toggle-killswitch.conf" ]]
  grep -Fxq '# original dispatcher' "$ROOT_DIR/etc/NetworkManager/dispatcher.d/50-dnscrypt-campus"
  [[ ! -e "$ROOT_DIR/etc/NetworkManager/dispatcher.d/90-dnscrypt-toggle" ]]
  grep -Fxq '# original WireGuard readiness guard' "$ROOT_DIR/etc/systemd/system/wg-quick@wg0.service.d/10-wait-dns.conf"
  [[ ! -e "$ROOT_DIR/etc/systemd/system/wg-quick@wg0.service.d/20-dnscrypt-toggle.conf" ]]
  assert_eq "$(readlink "$ROOT_DIR/etc/resolv.conf")" "$ROOT_DIR/etc/resolv.original"
  assert_eq "$(cat "$MOCK_STATE/dnscrypt-proxy.service.enabled")" disabled
  assert_eq "$(cat "$MOCK_STATE/dnscrypt-proxy.service.active")" inactive
  assert_eq "$(cat "$MOCK_STATE/systemd-resolved.service.enabled")" enabled
  assert_eq "$(cat "$MOCK_STATE/systemd-resolved.service.active")" active
  assert_eq "$(cat "$MOCK_STATE/dnscrypt-toggle-killswitch.service.enabled")" disabled
  assert_eq "$(cat "$MOCK_STATE/dnscrypt-toggle-killswitch.service.active")" inactive
  assert_eq "$(cat "$MOCK_STATE/dnscrypt-toggle-reconcile.service.enabled")" disabled
  assert_eq "$(cat "$MOCK_STATE/nft-table")" absent
  assert_eq "$(cat "$MOCK_STATE/link-dns")" stale
  [[ ! -e "$ROOT_DIR/run/dnscrypt-toggle-firewall" ]]
  [[ ! -e "$ROOT_DIR/run/lock/dnscrypt-toggle.lock" ]]
  [[ ! -s "$MOCK_STATE/ufw-untouched" ]]
}

"$TEST_MANAGER" enable
[[ -f "$ROOT_DIR/var/lib/dnscrypt-toggle/enabled" ]]
grep -Fq 'bootstrap_resolvers = []' "$ROOT_DIR/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
grep -Fq 'dns=none' "$ROOT_DIR/etc/NetworkManager/conf.d/99-dnscrypt-toggle.conf"
[[ ! -e "$ROOT_DIR/etc/NetworkManager/dispatcher.d/50-dnscrypt-campus" ]]
cmp -s "$PROJECT_DIR/90-dnscrypt-toggle" "$ROOT_DIR/etc/NetworkManager/dispatcher.d/90-dnscrypt-toggle"
grep -Fxq 'After=dnscrypt-toggle-reconcile.service' "$ROOT_DIR/etc/systemd/system/wg-quick@wg0.service.d/20-dnscrypt-toggle.conf"
grep -Fxq 'Restart=on-failure' "$ROOT_DIR/etc/systemd/system/wg-quick@wg0.service.d/20-dnscrypt-toggle.conf"
grep -Fxq '# original WireGuard readiness guard' "$ROOT_DIR/etc/systemd/system/wg-quick@wg0.service.d/10-wait-dns.conf"
grep -Fq -- '-t -f DEVICE connection show --active' "$MOCK_STATE/nmcli-log"
assert_eq "$(cat "$MOCK_STATE/nft-table")" present
assert_eq "$(cat "$MOCK_STATE/link-dns")" clean
if grep -Fq 'connection modify' "$MOCK_STATE/nmcli-log"; then exit 1; fi

# Required markers are not enough: any unexpected rule in the private table
# must make the structural check fail.
touch "$MOCK_STATE/nft-extra-rule"
if "$TEST_FIREWALL" check; then
  printf 'firewall check accepted an unexpected rule\n' >&2
  exit 1
fi
rm -f "$MOCK_STATE/nft-extra-rule"
"$TEST_FIREWALL" check

printf 'second-network\n' >"$MOCK_STATE/network"
"$TEST_MANAGER" dispatch wlan0 up
grep -Fq 'revert wlan0' "$MOCK_STATE/resolvectl-log"

printf 'normal\n' >"$MOCK_STATE/network"
"$TEST_MANAGER" dispatch wlan0 up

"$TEST_MANAGER" enable
[[ -f "$ROOT_DIR/var/lib/dnscrypt-toggle/enabled" ]]
assert_eq "$(cat "$MOCK_STATE/nft-table")" present

# A direct readiness check parses the configured endpoint without logging or
# embedding its value in any managed file.
"$TEST_MANAGER" wg-ready wg0
grep -Fq 'query --cache=no --legend=no --no-pager endpoint.test' "$MOCK_STATE/resolvectl-log"
if grep -Fq 'endpoint.test' "$ROOT_DIR/etc/systemd/system/wg-quick@wg0.service.d/20-dnscrypt-toggle.conf"; then exit 1; fi

touch "$MOCK_STATE/fail-wg-dns"
if wg_failure_output="$("$TEST_MANAGER" wg-ready wg0 2>&1)"; then
  printf 'unresolvable WireGuard endpoint unexpectedly passed readiness\n' >&2
  exit 1
fi
[[ -z "$wg_failure_output" ]]
rm -f "$MOCK_STATE/fail-wg-dns"

printf '[Peer]\nEndpoint = 192.0.2.1:51820\n' >"$ROOT_DIR/etc/wireguard/wg0.conf"
: >"$MOCK_STATE/resolvectl-log"
"$TEST_MANAGER" wg-ready wg0
if grep -Fq 'query --cache=no' "$MOCK_STATE/resolvectl-log"; then
  printf 'literal WireGuard endpoint unexpectedly triggered DNS\n' >&2
  exit 1
fi

printf '[Peer]\nEndpoint = malformed-endpoint\n' >"$ROOT_DIR/etc/wireguard/wg0.conf"
if "$TEST_MANAGER" wg-ready wg0; then
  printf 'malformed WireGuard endpoint unexpectedly passed readiness\n' >&2
  exit 1
fi
printf '[Peer]\nEndpoint = endpoint.test:51820\n' >"$ROOT_DIR/etc/wireguard/wg0.conf"

# Link-down handling must stay quick and successful even while upstream DNS is
# unavailable; the later up event performs the real health check.
touch "$MOCK_STATE/fail-dnscrypt" "$MOCK_STATE/fail-system-dns"
"$TEST_MANAGER" dispatch wlan0 down
rm -f "$MOCK_STATE/fail-dnscrypt" "$MOCK_STATE/fail-system-dns"

# With an intact persistent state, boot reconciliation must not restart either
# resolver service.  This is the regression for the v3 WireGuard race.
: >"$MOCK_STATE/systemctl-log"
"$TEST_MANAGER" boot
if grep -Eq '^restart (dnscrypt-proxy|systemd-resolved)\.service$' "$MOCK_STATE/systemctl-log"; then
  printf 'intact boot unexpectedly restarted a resolver service\n' >&2
  exit 1
fi

# Simulate a reboot: kernel firewall state disappears and the early unit loads it
# again before the boot reconciliation action runs.
printf 'absent\n' >"$MOCK_STATE/nft-table"
printf 'inactive\n' >"$MOCK_STATE/dnscrypt-toggle-killswitch.service.active"
systemctl start dnscrypt-toggle-killswitch.service
: >"$MOCK_STATE/systemctl-log"
"$TEST_MANAGER" boot
assert_eq "$(cat "$MOCK_STATE/nft-table")" present
assert_eq "$(cat "$MOCK_STATE/dnscrypt-toggle-killswitch.service.active")" active
if grep -Eq '^restart (dnscrypt-proxy|systemd-resolved)\.service$' "$MOCK_STATE/systemctl-log"; then
  printf 'normal reboot unexpectedly restarted a resolver service\n' >&2
  exit 1
fi

# An early restore failure must retain snapshot, marker and fail-closed table.
touch "$MOCK_STATE/fail-disable-dnscrypt" "$MOCK_STATE/fail-nft-delete"
if "$TEST_MANAGER" disable; then
  printf 'expected disable failure did not occur\n' >&2
  exit 1
fi
[[ -f "$ROOT_DIR/var/lib/dnscrypt-toggle/snapshot-complete" ]]
[[ -f "$ROOT_DIR/etc/dnscrypt-toggle-enabled" ]]
assert_eq "$(cat "$MOCK_STATE/nft-table")" present
rm -f "$MOCK_STATE/fail-disable-dnscrypt"

# A failure while removing the table occurs after file restoration.  The
# persistent guard must still remain until a later retry finishes everything.
if "$TEST_MANAGER" disable; then
  printf 'expected late disable failure did not occur\n' >&2
  exit 1
fi
[[ -f "$ROOT_DIR/var/lib/dnscrypt-toggle/snapshot-complete" ]]
[[ -f "$ROOT_DIR/etc/dnscrypt-toggle-enabled" ]]
assert_eq "$(cat "$MOCK_STATE/nft-table")" present
rm -f "$MOCK_STATE/fail-nft-delete"

# A stale lock pathname left by an older build is removed during the clean
# disable.  Subsequent idempotent disable/status calls must not recreate it.
touch "$ROOT_DIR/run/lock/dnscrypt-toggle.lock"
"$TEST_MANAGER" disable
assert_clean_restore
"$TEST_MANAGER" disable
"$TEST_MANAGER" status >/dev/null
[[ ! -e "$ROOT_DIR/run/dnscrypt-toggle-firewall" ]]
[[ ! -e "$ROOT_DIR/run/lock/dnscrypt-toggle.lock" ]]

printf 'mock enable/repair/reboot/disable tests: PASS\n'

"$TEST_MANAGER" enable
rm -f "$ROOT_DIR/var/lib/dnscrypt-toggle/enabled"
printf 'enabling\n' >"$ROOT_DIR/var/lib/dnscrypt-toggle/phase"
"$TEST_MANAGER" boot
assert_clean_restore
printf 'mock interrupted-transaction recovery test: PASS\n'

touch "$MOCK_STATE/fail-dnscrypt"
if "$TEST_MANAGER" enable; then
  printf 'expected enable failure did not occur\n' >&2
  exit 1
fi
assert_clean_restore
printf 'mock rollback test: PASS\n'

rm -f "$MOCK_STATE/fail-dnscrypt"
touch "$MOCK_STATE/fail-system-dns"
if "$TEST_MANAGER" enable; then
  printf 'expected post-firewall sanity failure did not occur\n' >&2
  exit 1
fi
assert_clean_restore
printf 'mock post-mutation rollback test: PASS\n'
rm -f "$MOCK_STATE/fail-system-dns"

# On a host without a local wg0 configuration, the shared implementation must
# not create a laptop-specific WireGuard drop-in.  An absent legacy dispatcher
# must also be restored as absent.
rm -f "$ROOT_DIR/etc/wireguard/wg0.conf"
rm -f "$ROOT_DIR/etc/NetworkManager/dispatcher.d/50-dnscrypt-campus"
rmdir "$ROOT_DIR/etc/systemd/system/NetworkManager.service.d"
"$TEST_MANAGER" enable
[[ ! -e "$ROOT_DIR/var/lib/dnscrypt-toggle/wg-integration" ]]
[[ ! -e "$ROOT_DIR/etc/systemd/system/wg-quick@wg0.service.d/20-dnscrypt-toggle.conf" ]]
[[ ! -e "$ROOT_DIR/etc/NetworkManager/dispatcher.d/50-dnscrypt-campus" ]]
"$TEST_MANAGER" disable
[[ ! -e "$ROOT_DIR/var/lib/dnscrypt-toggle" ]]
[[ ! -e "$ROOT_DIR/etc/dnscrypt-toggle-enabled" ]]
[[ ! -e "$ROOT_DIR/etc/NetworkManager/dispatcher.d/50-dnscrypt-campus" ]]
[[ ! -e "$ROOT_DIR/etc/NetworkManager/dispatcher.d/90-dnscrypt-toggle" ]]
[[ ! -e "$ROOT_DIR/etc/systemd/system/NetworkManager.service.d" ]]
assert_eq "$(cat "$MOCK_STATE/nft-table")" absent
printf 'mock optional-WireGuard/absent-parent restore test: PASS\n'
