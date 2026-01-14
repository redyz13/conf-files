#!/bin/bash
set -euo pipefail

# CHANGE THESE ONLY IF YOUR LAYOUT IS DIFFERENT
root_dev="/dev/nvme0n1p2"
boot_dev="/dev/nvme0n1p1"
backup_base="/mnt/backup/arch-backups/mangopi"

mnt_root="/mnt/restore-root"
mnt_boot="$mnt_root/boot"

log() { echo "[restore] $1"; }

rollback() {
  log "Error occurred, rolling back"
  umount -R "$mnt_root" 2>/dev/null || true
}
trap rollback ERR

log "Mounting backup disk"
mount /dev/sda1 /mnt/backup

log "Formatting root"
mkfs.btrfs -f "$root_dev"

log "Formatting boot"
mkfs.vfat -F32 "$boot_dev"

log "Mounting target filesystem"
mkdir -p "$mnt_root"
mount "$root_dev" "$mnt_root"

mkdir -p "$mnt_boot"
mount "$boot_dev" "$mnt_boot"

log "Restoring root filesystem"
rsync -aHAX --numeric-ids "$backup_base/root/" "$mnt_root/"

log "Restoring boot"
rsync -aHAX "$backup_base/boot/" "$mnt_boot/"

log "Restoring fstab"
cp "$backup_base/meta/fstab" "$mnt_root/etc/fstab"

log "Syncing data"
sync

log "Unmounting cleanly"
umount -R "$mnt_root"

log "Restore completed successfully"
log "You can now reboot"

