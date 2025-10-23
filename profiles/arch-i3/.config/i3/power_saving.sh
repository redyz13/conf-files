#!/bin/bash

# Power saving toggle script
# Remember to add the following line to visudo so i3 can run this without password:
# redyz ALL=(ALL) NOPASSWD: /usr/bin/tlp bat, /usr/bin/tlp ac, /usr/bin/tee /etc/tlp.d/99-mode.conf

STATE_FILE="$HOME/.config/i3/.laptop-mode"
BRIGHTNESS_LOW=35%
BRIGHTNESS_HIGH=75%
MODE_FILE="/etc/tlp.d/99-mode.conf"

if [ -f "$STATE_FILE" ]; then
  echo "[INFO] Disabling power saving mode..."
  brightnessctl set "$BRIGHTNESS_HIGH"
  echo "[INFO] Switching TLP to AC mode..."
  echo -e "TLP_PERSISTENT_DEFAULT=1\nTLP_DEFAULT_MODE=AC" | sudo tee "$MODE_FILE" >/dev/null
  sudo tlp ac
  notify-send "Power saving disabled"
  rm "$STATE_FILE"
else
  echo "[INFO] Enabling power saving mode..."
  brightnessctl set "$BRIGHTNESS_LOW"
  echo "[INFO] Switching TLP to battery mode..."
  echo -e "TLP_PERSISTENT_DEFAULT=1\nTLP_DEFAULT_MODE=BAT" | sudo tee "$MODE_FILE" >/dev/null
  sudo tlp bat
  notify-send "Power saving enabled"
  touch "$STATE_FILE"
fi

