#!/usr/bin/env bash
set -euo pipefail

# ==================================
# ArchLain systemd preset-diff export
# ==================================
# Exports only the delta vs systemd presets:
# - enabled even though preset says disabled  (additions)
# - disabled even though preset says enabled  (removals, optional)
#
# Usage:
#   ./export_systemd_delta.sh <output_directory>
#
# Generated files:
# - enabled-vs-preset-disabled.txt   (enabled but preset disabled)
# - disabled-vs-preset-enabled.txt   (disabled but preset enabled)
# - enabled-units.txt                (all enabled units)
# - enabled-symlinks.txt             (enabled units via /etc/systemd/system symlinks)
# - enabled-unit-names-from-symlinks.txt (unit names derived from symlinks, includes @instances)
# - export-date.txt                  (ISO timestamp)
# ==================================

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <output_directory>"
  exit 1
fi

OUTDIR="$1"
mkdir -p "$OUTDIR"

echo "→ Exporting systemd delta vs presets to: $OUTDIR"

HEADER="UNIT FILE$(printf '\t')STATE$(printf '\t')PRESET"

# All enabled (current baseline)
{
  echo -e "$HEADER"
  systemctl list-unit-files --no-pager | awk '$2=="enabled"{print}'
} > "$OUTDIR/enabled-units.txt"

# Additions vs Arch base preset:
# enabled, but preset recommends disabled
{
  echo -e "$HEADER"
  systemctl list-unit-files --no-pager | awk '$2=="enabled" && $3=="disabled"{print}'
} > "$OUTDIR/enabled-vs-preset-disabled.txt"

# Removals vs Arch base preset (optional but useful):
# disabled, but preset recommends enabled
{
  echo -e "$HEADER"
  systemctl list-unit-files --no-pager | awk '$2=="disabled" && $3=="enabled"{print}'
} > "$OUTDIR/disabled-vs-preset-enabled.txt"

{
  echo -e "SYMLINK\tTARGET"
  find /etc/systemd/system -type l \( -name '*.service' -o -name '*.timer' -o -name '*.socket' -o -name '*.target' -o -name '*.path' -o -name '*.mount' -o -name '*.automount' \) \
    -printf '%p\t%l\n' | sort
} > "$OUTDIR/enabled-symlinks.txt"

{
  echo -e "UNIT"
  find /etc/systemd/system -type l \( -name '*.service' -o -name '*.timer' -o -name '*.socket' -o -name '*.target' -o -name '*.path' -o -name '*.mount' -o -name '*.automount' \) \
    -printf '%f\n' | sort -u
} > "$OUTDIR/enabled-unit-names-from-symlinks.txt"

date -Iseconds > "$OUTDIR/export-date.txt"

echo "Export completed successfully."
echo "Files generated:"
ls -1 "$OUTDIR"
