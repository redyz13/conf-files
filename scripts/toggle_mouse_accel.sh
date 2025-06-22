#!/bin/bash

MOUSE_NAME="$1"

if [ -z "$MOUSE_NAME" ]; then
    echo "Usage: $0 \"Exact Mouse Name\""
    exit 1
fi

DEVICE_LINE=$(xinput list | awk -v name="$MOUSE_NAME" '
    /slave[[:space:]]+pointer/ && $0 ~ name && $0 !~ /Keyboard/ {
        match($0, /↳[[:space:]]+.*[[:space:]]+id=[0-9]+/, m)
        if (m[0] ~ "↳[[:space:]]+"name"[[:space:]]+id=") print $0
    }')

DEVICE_ID=$(echo "$DEVICE_LINE" | grep -o 'id=[0-9]*' | cut -d= -f2)

if [ -z "$DEVICE_ID" ]; then
    echo "Mouse not found: \"$MOUSE_NAME\""
    exit 1
fi

PROPERTY_LINE=$(xinput list-props "$DEVICE_ID" | grep -i "libinput Accel Profile Enabled" | grep -v "Default")
PROPERTY_ID=$(echo "$PROPERTY_LINE" | sed -n 's/.*(\([0-9]\+\)):.*/\1/p')
VALUES=$(echo "$PROPERTY_LINE" | grep -Eo '[01], [01]' | tr -d ',')

if [ -z "$PROPERTY_ID" ] || [ -z "$VALUES" ]; then
    echo "Property not found or not supported."
    exit 1
fi

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
    if xinput set-prop "$DEVICE_ID" "$PROPERTY_ID" 1 0; then
        echo "$CONFIG_ADAPTIVE" | sudo tee "$CONFIG_FILE" > /dev/null
        echo "Mouse acceleration enabled (adaptive profile, persisted)"
    else
        echo "Failed to apply adaptive profile. Config file not written."
        exit 1
    fi
else
    if xinput set-prop "$DEVICE_ID" "$PROPERTY_ID" 0 1; then
        echo "$CONFIG_FLAT" | sudo tee "$CONFIG_FILE" > /dev/null
        echo "Mouse acceleration disabled (flat profile, persisted)"
    else
        echo "Failed to apply flat profile. Config file not written."
        exit 1
    fi
fi

