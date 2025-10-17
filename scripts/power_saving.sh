#!/bin/bash

STATE_FILE="$HOME/.config/i3/.laptop-mode"
BRIGHTNESS_LOW=35%
BRIGHTNESS_HIGH=75%

if [ -f "$STATE_FILE" ]; then
  echo "[INFO] Disabling power saving mode..."
  brightnessctl set "$BRIGHTNESS_HIGH"
  echo "[INFO] Switching TLP to AC mode..."
  pkexec tlp ac
  notify-send "Power saving disabled"
  rm "$STATE_FILE"
else
  echo "[INFO] Enabling power saving mode..."
  brightnessctl set "$BRIGHTNESS_LOW"
  echo "[INFO] Switching TLP to battery mode..."
  pkexec tlp bat
  notify-send "Power saving enabled"
  touch "$STATE_FILE"
fi

