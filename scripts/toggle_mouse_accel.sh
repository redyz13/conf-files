#!/bin/bash

MOUSE_NAME="Logitech G203 Prodigy Gaming Mouse"
DEVICE_LINE=$(xinput list | grep -i "$MOUSE_NAME" | grep -v 'Keyboard')
DEVICE_ID=$(echo "$DEVICE_LINE" | grep -o 'id=[0-9]*' | cut -d= -f2)

if [ -z "$DEVICE_ID" ]; then
    echo "Mouse not found."
    exit 1
fi

PROPERTY_NAME="libinput Accel Profile Enabled"
PROPERTY_LINE=$(xinput list-props "$DEVICE_ID" | grep -i "$PROPERTY_NAME" | grep -v 'Default')
PROPERTY_ID=$(echo "$PROPERTY_LINE" | sed -n 's/.*(\([0-9]\+\)):.*/\1/p')
VALUES=$(echo "$PROPERTY_LINE" | grep -Eo '[01], [01]' | tr -d ',')

if [ -z "$PROPERTY_ID" ] || [ -z "$VALUES" ]; then
    echo "Property not found or not supported."
    exit 1
fi

CURRENT_ADAPTIVE=$(echo "$VALUES" | awk '{print $1}')
CURRENT_FLAT=$(echo "$VALUES" | awk '{print $2}')

CONFIG_FILE="/etc/X11/xorg.conf.d/90-mouse-accel.conf"

CONFIG_FLAT="Section \"InputClass\"
    Identifier \"Mouse Accel Toggle\"
    MatchProduct \"$MOUSE_NAME\"
    Driver \"libinput\"
    Option \"AccelProfile\" \"flat\"
EndSection"

CONFIG_ADAPTIVE="Section \"InputClass\"
    Identifier \"Mouse Accel Toggle\"
    MatchProduct \"$MOUSE_NAME\"
    Driver \"libinput\"
    Option \"AccelProfile\" \"adaptive\"
EndSection"

if [ "$CURRENT_FLAT" = "1" ]; then
    xinput set-prop "$DEVICE_ID" "$PROPERTY_ID" 1 0
    echo "$CONFIG_ADAPTIVE" | sudo tee "$CONFIG_FILE" > /dev/null
    echo "Mouse acceleration enabled (adaptive profile, persisted)"
else
    xinput set-prop "$DEVICE_ID" "$PROPERTY_ID" 0 1
    echo "$CONFIG_FLAT" | sudo tee "$CONFIG_FILE" > /dev/null
    echo "Mouse acceleration disabled (flat profile, persisted)"
fi

