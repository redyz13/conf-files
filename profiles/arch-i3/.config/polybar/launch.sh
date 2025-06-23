#!/usr/bin/env bash

killall -q polybar

while pgrep -u $UID -x polybar >/dev/null; do sleep 0.2; done

BATTERY=$(ls /sys/class/power_supply/ | grep -E '^BAT' | head -n1)
ADAPTER=$(ls /sys/class/power_supply/ | grep -E '^(AC|ACAD|ADP)' | head -n1)

# Fallback
BATTERY=${BATTERY:-BAT1}
ADAPTER=${ADAPTER:-AC}

export BATTERY
export ADAPTER

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

