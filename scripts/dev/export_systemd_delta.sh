#!/usr/bin/env bash
set -euo pipefail

# ==================================
# ArchLain systemd preset-diff export
# ==================================
# Exports both:
# - system units
# - user units
#
# Usage:
#   ./export_systemd_delta.sh <output_directory>
#
# Generated files:
#
# system/
# - enabled-vs-preset-disabled.txt       (enabled but preset disabled)
# - disabled-vs-preset-enabled.txt       (disabled but preset enabled)
# - enabled-units.txt                    (all enabled system units)
# - enabled-symlinks.txt                 (enabled system units via /etc/systemd/system symlinks)
# - enabled-unit-names-from-symlinks.txt (system unit names derived from symlinks, includes @instances)
# - enabled-wants-symlinks.txt           (explicit system enables via *.wants symlinks)
# - enabled-wants-unit-names.txt         (system unit names derived from *.wants symlinks)
#
# user/
# - enabled-units.txt                    (all enabled user units)
# - enabled-vs-preset-disabled.txt       (enabled user units even though preset says disabled)
# - disabled-vs-preset-enabled.txt       (disabled user units even though preset says enabled)
# - unit-files-in-config.txt             (all user unit files present in ~/.config/systemd/user)
# - services-in-config.txt               (user service files present in ~/.config/systemd/user)
# - timers-in-config.txt                 (user timer files present in ~/.config/systemd/user)
#
# common/
# - export-date.txt                      (ISO timestamp)
# ==================================

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <output_directory>"
  exit 1
fi

OUTDIR="$1"
SYSTEM_OUTDIR="$OUTDIR/system"
USER_OUTDIR="$OUTDIR/user"
COMMON_OUTDIR="$OUTDIR/common"

mkdir -p "$SYSTEM_OUTDIR" "$USER_OUTDIR" "$COMMON_OUTDIR"

echo "→ Exporting full systemd delta (system + user) to: $OUTDIR"

HEADER="UNIT FILE$(printf '\t')STATE$(printf '\t')PRESET"
USER_SYSTEMD_DIR="${HOME}/.config/systemd/user"

# -------------------------
# System units
# -------------------------

{
  echo -e "$HEADER"
  systemctl list-unit-files --no-pager | awk '$2=="enabled"{print}'
} > "$SYSTEM_OUTDIR/enabled-units.txt"

{
  echo -e "$HEADER"
  systemctl list-unit-files --no-pager | awk '$2=="enabled" && $3=="disabled"{print}'
} > "$SYSTEM_OUTDIR/enabled-vs-preset-disabled.txt"

{
  echo -e "$HEADER"
  systemctl list-unit-files --no-pager | awk '$2=="disabled" && $3=="enabled"{print}'
} > "$SYSTEM_OUTDIR/disabled-vs-preset-enabled.txt"

{
  echo -e "SYMLINK\tTARGET"
  find /etc/systemd/system -type l \
    \( -name '*.service' -o -name '*.timer' -o -name '*.socket' -o -name '*.target' -o -name '*.path' -o -name '*.mount' -o -name '*.automount' \) \
    -printf '%p\t%l\n' | sort
} > "$SYSTEM_OUTDIR/enabled-symlinks.txt"

{
  echo -e "UNIT"
  find /etc/systemd/system -type l \
    \( -name '*.service' -o -name '*.timer' -o -name '*.socket' -o -name '*.target' -o -name '*.path' -o -name '*.mount' -o -name '*.automount' \) \
    -printf '%f\n' | sort -u
} > "$SYSTEM_OUTDIR/enabled-unit-names-from-symlinks.txt"

{
  echo -e "SYMLINK\tTARGET"
  find /etc/systemd/system -type l -regextype posix-extended \
    -regex '.*/[^/]+\.wants/[^/]+\.(service|timer|socket|target|path|mount|automount)$' \
    -printf '%p\t%l\n' | sort
} > "$SYSTEM_OUTDIR/enabled-wants-symlinks.txt"

{
  echo -e "UNIT"
  find /etc/systemd/system -type l -regextype posix-extended \
    -regex '.*/[^/]+\.wants/[^/]+\.(service|timer|socket|target|path|mount|automount)$' \
    -printf '%f\n' | sort -u
} > "$SYSTEM_OUTDIR/enabled-wants-unit-names.txt"

# -------------------------
# User units
# -------------------------

if systemctl --user show-environment >/dev/null 2>&1; then
  {
    echo -e "$HEADER"
    systemctl --user list-unit-files --no-pager | awk '$2=="enabled"{print}'
  } > "$USER_OUTDIR/enabled-units.txt"

  {
    echo -e "$HEADER"
    systemctl --user list-unit-files --no-pager | awk '$2=="enabled" && $3=="disabled"{print}'
  } > "$USER_OUTDIR/enabled-vs-preset-disabled.txt"

  {
    echo -e "$HEADER"
    systemctl --user list-unit-files --no-pager | awk '$2=="disabled" && $3=="enabled"{print}'
  } > "$USER_OUTDIR/disabled-vs-preset-enabled.txt"
else
  {
    echo "User systemd session not available."
  } > "$USER_OUTDIR/enabled-units.txt"

  {
    echo "User systemd session not available."
  } > "$USER_OUTDIR/enabled-vs-preset-disabled.txt"

  {
    echo "User systemd session not available."
  } > "$USER_OUTDIR/disabled-vs-preset-enabled.txt"
fi

if [[ -d "$USER_SYSTEMD_DIR" ]]; then
  {
    echo -e "FILE"
    find "$USER_SYSTEMD_DIR" -maxdepth 1 -type f | sort
  } > "$USER_OUTDIR/unit-files-in-config.txt"

  {
    echo -e "FILE"
    find "$USER_SYSTEMD_DIR" -maxdepth 1 -type f -name '*.service' | sort
  } > "$USER_OUTDIR/services-in-config.txt"

  {
    echo -e "FILE"
    find "$USER_SYSTEMD_DIR" -maxdepth 1 -type f -name '*.timer' | sort
  } > "$USER_OUTDIR/timers-in-config.txt"
else
  {
    echo "Directory not found: $USER_SYSTEMD_DIR"
  } > "$USER_OUTDIR/unit-files-in-config.txt"

  {
    echo "Directory not found: $USER_SYSTEMD_DIR"
  } > "$USER_OUTDIR/services-in-config.txt"

  {
    echo "Directory not found: $USER_SYSTEMD_DIR"
  } > "$USER_OUTDIR/timers-in-config.txt"
fi

date -Iseconds > "$COMMON_OUTDIR/export-date.txt"

echo "Export completed successfully."
echo "Files generated:"
find "$OUTDIR" -maxdepth 2 -type f | sort
