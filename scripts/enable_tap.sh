#!/bin/bash

CONFIG_FILE="/etc/X11/xorg.conf.d/40-libinput-touchpad.conf"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root"
  exit 1
fi

mkdir -p /etc/X11/xorg.conf.d

cat > "$CONFIG_FILE" <<EOF
Section "InputClass"
    Identifier "Enable tap-to-click"
    MatchIsTouchpad "on"
    MatchDevicePath "/dev/input/event*"
    Driver "libinput"
    Option "Tapping" "on"
    Option "TappingDrag" "on"
    Option "TappingButtonMap" "lrm"
EndSection
EOF

echo "Tap-to-click config created at $CONFIG_FILE"
echo "Please restart X or reboot to apply"

