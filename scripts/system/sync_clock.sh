#!/bin/bash
set -e

echo "[+] Setting timezone to Europe/Rome..."
timedatectl set-timezone Europe/Rome

echo "[+] Enabling NTP..."
timedatectl set-ntp true

echo "[+] Current clock status:"
timedatectl

echo "[✓] Time configuration complete."

