#!/bin/bash

set -e

if ! command -v ufw &> /dev/null; then
    echo "Error: ufw is not installed. Please install it first (e.g. sudo pacman -S ufw)."
    exit 1
fi

sudo ufw default deny incoming
sudo ufw default allow outgoing

sudo ufw enable
sudo systemctl enable --now ufw

sudo ufw status verbose
systemctl is-enabled ufw
systemctl status ufw | grep Active

