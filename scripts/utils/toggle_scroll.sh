#!/bin/bash

TOUCHPAD_NAME=$(xinput list | grep -i 'touchpad' | awk -F'\t' '{print $1}' | sed 's/^[↳ ]*//')
DEVICE_ID=$(xinput list | grep -i 'touchpad' | grep -o 'id=[0-9]*' | head -n 1 | cut -d= -f2)

if [ -z "$DEVICE_ID" ] || [ -z "$TOUCHPAD_NAME" ]; then
    echo "Touchpad not found."
    exit 1
fi

PROPERTY="libinput Natural Scrolling Enabled"
CURRENT=$(xinput list-props "$DEVICE_ID" | grep "$PROPERTY" | head -n 1 | awk '{print $NF}')

CONFIG_FILE="/etc/X11/xorg.conf.d/30-touchpad-scroll.conf"
CONFIG_ON='Section "InputClass"
    Identifier "Touchpad natural scroll"
    MatchIsTouchpad "on"
    Driver "libinput"
    Option "NaturalScrolling" "true"
EndSection'

CONFIG_OFF='Section "InputClass"
    Identifier "Touchpad natural scroll"
    MatchIsTouchpad "on"
    Driver "libinput"
    Option "NaturalScrolling" "false"
EndSection'

if [ "$CURRENT" = "1" ]; then
    xinput set-prop "$DEVICE_ID" "$PROPERTY" 0
    echo "$CONFIG_OFF" | sudo tee "$CONFIG_FILE" > /dev/null
    echo "Natural scrolling disabled (and persisted)"
else
    xinput set-prop "$DEVICE_ID" "$PROPERTY" 1
    echo "$CONFIG_ON" | sudo tee "$CONFIG_FILE" > /dev/null
    echo "Natural scrolling enabled (and persisted)"
fi

