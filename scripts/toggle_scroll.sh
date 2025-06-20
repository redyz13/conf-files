#!/bin/bash

DEVICE_ID=$(xinput list | grep -i 'touchpad' | grep -o 'id=[0-9]*' | cut -d= -f2)

if [ -z "$DEVICE_ID" ]; then
    echo "Touchpad not found."
    exit 1
fi

PROPERTY_NAME="libinput Natural Scrolling Enabled"
CURRENT_STATE=$(xinput list-props "$DEVICE_ID" | grep "$PROPERTY_NAME" | head -n 1 | awk '{print $NF}')

if [ "$CURRENT_STATE" = "1" ]; then
    xinput set-prop "$DEVICE_ID" "$PROPERTY_NAME" 0
    echo "Natural scrolling disabled"
else
    xinput set-prop "$DEVICE_ID" "$PROPERTY_NAME" 1
    echo "Natural scrolling enabled"
fi

