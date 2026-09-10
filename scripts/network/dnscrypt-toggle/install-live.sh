#!/usr/bin/env bash
set -Eeuo pipefail

readonly SAFE_PATH="/usr/local/sbin:/usr/local/bin:/usr/bin"
PATH="$SAFE_PATH"
export PATH

SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

readonly -a INSTALL_SOURCES=(
  "$SOURCE_DIR/dnscrypt-toggle"
  "$SOURCE_DIR/dnscrypt-toggle-firewall"
  "$SOURCE_DIR/90-dnscrypt-toggle"
  "$SOURCE_DIR/dnscrypt-toggle-killswitch.service"
  "$SOURCE_DIR/dnscrypt-toggle-reconcile.service"
)
readonly -a INSTALL_TARGETS=(
  /usr/local/sbin/dnscrypt-toggle
  /usr/local/libexec/dnscrypt-toggle-firewall
  /usr/local/libexec/dnscrypt-toggle-dispatcher
  /etc/systemd/system/dnscrypt-toggle-killswitch.service
  /etc/systemd/system/dnscrypt-toggle-reconcile.service
)
readonly -a INSTALL_MODES=(0755 0755 0755 0644 0644)

CREATED_TARGETS=()

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

rollback_partial_install() {
  local rc=$? target
  trap - ERR
  if (( rc != 0 )); then
    for target in "${CREATED_TARGETS[@]}"; do
      rm -f -- "$target" || true
    done
    systemctl daemon-reload >/dev/null 2>&1 || true
    printf 'ERROR: installation failed; newly created implementation files were removed\n' >&2
  fi
  exit "$rc"
}

if (( EUID != 0 )); then
  exec sudo -- "$0" "$@"
fi

[[ ! -e /var/lib/dnscrypt-toggle ]] ||
  die "the old toggle is still active or left state behind; disable it before installing"
[[ ! -e /etc/dnscrypt-toggle-enabled ]] ||
  die "orphaned /etc/dnscrypt-toggle-enabled marker exists"

if command -v ufw >/dev/null 2>&1; then
  legacy_rules="$(
    LC_ALL=C ufw status numbered 2>/dev/null |
      grep -E '(53/(udp|tcp)|853/(udp|tcp)).*(DENY OUT|ALLOW OUT)' || true
  )"
  if [[ -n "$legacy_rules" ]]; then
    printf '%s\n' "$legacy_rules" >&2
    die "legacy DNS rules remain in UFW; clean them before installing"
  fi
fi

if /usr/bin/nft list table inet dnscrypt_toggle >/dev/null 2>&1; then
  die "table inet dnscrypt_toggle already exists; refusing to overwrite it"
fi

if systemctl is-enabled --quiet nftables.service || systemctl is-active --quiet nftables.service; then
  die "nftables.service is enabled or active and could replace the managed table"
fi

for unit in dnscrypt-toggle-killswitch.service dnscrypt-toggle-reconcile.service; do
  if systemctl is-active --quiet "$unit" || systemctl is-enabled --quiet "$unit"; then
    die "$unit is already active or enabled"
  fi
done

for command_name in bash cmp grep install nft systemctl systemd-analyze; do
  command -v "$command_name" >/dev/null 2>&1 || die "missing required command: $command_name"
done


bash -n \
  "$SOURCE_DIR/dnscrypt-toggle" \
  "$SOURCE_DIR/dnscrypt-toggle-firewall" \
  "$SOURCE_DIR/90-dnscrypt-toggle"

for index in "${!INSTALL_TARGETS[@]}"; do
  source_path="${INSTALL_SOURCES[$index]}"
  target_path="${INSTALL_TARGETS[$index]}"
  [[ -f "$source_path" && ! -L "$source_path" ]] || die "invalid source file: $source_path"
  if [[ -e "$target_path" || -L "$target_path" ]]; then
    [[ -f "$target_path" && ! -L "$target_path" ]] || die "unsafe existing destination: $target_path"
    cmp -s -- "$source_path" "$target_path" || die "existing implementation differs: $target_path"
  else
    CREATED_TARGETS+=("$target_path")
  fi
done

trap rollback_partial_install ERR
for index in "${!INSTALL_TARGETS[@]}"; do
  install -D -o root -g root -m "${INSTALL_MODES[$index]}" \
    "${INSTALL_SOURCES[$index]}" "${INSTALL_TARGETS[$index]}"
done
systemctl daemon-reload
/usr/local/libexec/dnscrypt-toggle-firewall validate
systemd-analyze verify \
  /etc/systemd/system/dnscrypt-toggle-killswitch.service \
  /etc/systemd/system/dnscrypt-toggle-reconcile.service
trap - ERR

printf '%s\n' \
  'OK: implementation installed but still disabled.' \
  'Next: sudo /usr/local/sbin/dnscrypt-toggle enable'
