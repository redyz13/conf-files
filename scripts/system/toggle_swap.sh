#!/bin/bash

SWAPFILE="/btrfs_swap/swapfile"
FSTAB="/etc/fstab"

if [ -f "$SWAPFILE" ]; then
    echo "Swapfile found, removing..."
    sudo swapoff "$SWAPFILE" || echo "Swap not active or already disabled"
    sudo rm "$SWAPFILE"
    sudo sed -i '\|'"$SWAPFILE"' none swap defaults 0 0|d' "$FSTAB"
    echo "Swapfile removed."
else
    if [ -z "$1" ]; then
        echo "Usage: $0 <swap_size_in_GB>"
        exit 1
    fi

    SIZE_GB="$1"

    echo "Creating $SIZE_GB GB swapfile in $SWAPFILE..."

    sudo mkdir -p /btrfs_swap
    sudo chattr +C /btrfs_swap

    sudo dd if=/dev/zero of="$SWAPFILE" bs=1M count=$((SIZE_GB * 1024)) status=progress
    sudo chmod 600 "$SWAPFILE"
    sudo mkswap "$SWAPFILE"
    sudo swapon "$SWAPFILE"
    echo "$SWAPFILE none swap defaults 0 0" | sudo tee -a "$FSTAB"

    echo "$SIZE_GB GB swapfile created and enabled."
fi

