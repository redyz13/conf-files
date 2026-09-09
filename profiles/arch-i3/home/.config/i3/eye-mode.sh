#!/usr/bin/env bash

state="${XDG_RUNTIME_DIR}/archlain-eye-mode"

if [[ -e "$state" ]]; then
    gammastep -x
    rm -f "$state"
    dunstify -r 4600 "Eye Mode" "OFF · 6500K"
else
    gammastep -P -O 4600
    touch "$state"
    dunstify -r 4600 "Eye Mode" "ON · 4600K"
fi
