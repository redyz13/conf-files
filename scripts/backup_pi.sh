#!/bin/bash
set -euo pipefail

backup_base="/mnt/backup/arch-backups/mangopi"
root_dst="$backup_base/root"
boot_dst="$backup_base/boot"
meta_dst="$backup_base/meta"

log() { echo "[backup] $1"; }

# Ensure backup disk is mounted
if ! mountpoint -q /mnt/backup; then
  echo "Backup disk not mounted"
  exit 1
fi

log "Creating directory structure"
mkdir -p "$root_dst" "$boot_dst" "$meta_dst"

log "Saving metadata"
lsblk -f > "$meta_dst/lsblk.txt"
blkid > "$meta_dst/blkid.txt"
findmnt -R / > "$meta_dst/findmnt.txt"
cp /etc/fstab "$meta_dst/fstab"

log "Backing up /boot"
rsync -aHAX --delete /boot/ "$boot_dst/"

log "Backing up root filesystem"
rsync -aHAX --numeric-ids --delete \
  --exclude={"/proc/*","/sys/*","/dev/*","/run/*","/tmp/*","/mnt/*","/media/*","/lost+found"} \
  / "$root_dst/"

log "Backup completed successfully"

