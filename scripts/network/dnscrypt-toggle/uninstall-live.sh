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

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

if (( EUID != 0 )); then
  exec sudo -- "$0" "$@"
fi

[[ ! -e /var/lib/dnscrypt-toggle ]] || die "disable dnscrypt-toggle first"
[[ ! -e /etc/dnscrypt-toggle-enabled ]] || die "guard marker still exists"

if /usr/bin/nft list table inet dnscrypt_toggle >/dev/null 2>&1; then
  die "managed nftables table still exists; disable dnscrypt-toggle first"
fi

for unit in dnscrypt-toggle-killswitch.service dnscrypt-toggle-reconcile.service; do
  if systemctl is-active --quiet "$unit" || systemctl is-enabled --quiet "$unit"; then
    die "$unit is still active or enabled"
  fi
done

for index in "${!INSTALL_TARGETS[@]}"; do
  source_path="${INSTALL_SOURCES[$index]}"
  target_path="${INSTALL_TARGETS[$index]}"
  [[ -e "$target_path" || -L "$target_path" ]] || continue
  [[ -f "$target_path" && ! -L "$target_path" ]] || die "unsafe installed path: $target_path"
  cmp -s -- "$source_path" "$target_path" || die "installed implementation was modified: $target_path"
done

rm -f -- "${INSTALL_TARGETS[@]}"
rm -f -- /run/lock/dnscrypt-toggle.lock /run/lock/dnscrypt-toggle-firewall.lock

rm -rf -- /run/dnscrypt-toggle-firewall

systemctl daemon-reload
systemctl reset-failed dnscrypt-toggle-killswitch.service dnscrypt-toggle-reconcile.service >/dev/null 2>&1 || true

printf '%s\n' 'OK: dnscrypt-toggle implementation removed.'
