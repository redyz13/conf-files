#!/usr/bin/env bash
set -euo pipefail

# ==================================
# ArchLain package export script
# ==================================
# This script exports installed package lists
# into a user-defined output directory.
#
# Usage:
#   ./archlain-export-pkglist.sh <output_directory>
#
# Generated files:
# - pkglist-pacman.txt         (official repo packages)
# - pkglist-aur.txt            (AUR / foreign packages)
# - pkglist-with-versions.txt  (all packages with versions)
# - kernel.txt                 (running kernel version)
# - linux-package.txt          (installed linux package)
# - export-date.txt            (ISO timestamp)
# ==================================

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <output_directory>"
  exit 1
fi

OUTDIR="$1"

# Create output directory if it does not exist
mkdir -p "$OUTDIR"

echo "→ Exporting package lists to: $OUTDIR"

# Export official repository packages
pacman -Qqe > "$OUTDIR/pkglist-pacman.txt"

# Export AUR / foreign packages
pacman -Qqm > "$OUTDIR/pkglist-aur.txt"

# Export full package list with versions (debug / snapshot)
pacman -Q > "$OUTDIR/pkglist-with-versions.txt"

# Export basic system metadata
uname -r > "$OUTDIR/kernel.txt"
pacman -Q linux > "$OUTDIR/linux-package.txt" || true
date -Iseconds > "$OUTDIR/export-date.txt"

echo "Export completed successfully."
echo "Files generated:"
ls -1 "$OUTDIR"

