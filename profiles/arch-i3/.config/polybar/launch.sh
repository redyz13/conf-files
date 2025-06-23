#!/usr/bin/env bash

killall -q polybar

while pgrep -u $UID -x polybar >/dev/null; do sleep 0.2; done

if type "xrandr"; then
    MON_PRIMARY=$(xrandr --query | grep " connected primary" | cut -d" " -f1)
    MON_SECONDARY=$(xrandr --query | grep " connected" | grep -v "$MON_PRIMARY" | cut -d" " -f1)

    MONITOR=$MON_PRIMARY polybar --reload bar_top &

    MONITOR=$MON_PRIMARY polybar --reload bar_bottom &

    if [ -n "$MON_SECONDARY" ]; then
        MONITOR=$MON_SECONDARY polybar --reload bar_top &
        MONITOR=$MON_SECONDARY polybar --reload bar_bottom &
    fi
else
    polybar --reload bar_top &
    polybar --reload bar_bottom &
fi

echo "Polybar launched..."

