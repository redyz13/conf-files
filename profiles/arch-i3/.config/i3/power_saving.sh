#!/bin/bash

#
# Power saving toggle script (for i3)
# Remember to add to visudo:
# redyz ALL=(ALL) NOPASSWD: /usr/bin/tlp bat, /usr/bin/tlp ac, /usr/bin/tee /etc/tlp.d/99-mode.conf

BRIGHTNESS_LOW=35%
BRIGHTNESS_HIGH=75%
MODE_FILE="/etc/tlp.d/99-mode.conf"

if grep -q "TLP_DEFAULT_MODE=BAT" "$MODE_FILE" 2>/dev/null; then
  echo "[INFO] Disabling power saving mode..."
  brightnessctl set "$BRIGHTNESS_HIGH"
  echo "[INFO] Switching TLP to AC mode..."
  echo -e "TLP_PERSISTENT_DEFAULT=1\nTLP_DEFAULT_MODE=AC" | sudo tee "$MODE_FILE" >/dev/null
  sudo tlp ac
  notify-send "Power saving disabled"
else
  echo "[INFO] Enabling power saving mode..."
  brightnessctl set "$BRIGHTNESS_LOW"
  echo "[INFO] Switching TLP to battery mode..."
  echo -e "TLP_PERSISTENT_DEFAULT=1\nTLP_DEFAULT_MODE=BAT" | sudo tee "$MODE_FILE" >/dev/null
  sudo tlp bat
  notify-send "Power saving enabled"
fi

