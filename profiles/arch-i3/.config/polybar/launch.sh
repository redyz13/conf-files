#!/usr/bin/env bash

killall -q polybar

while pgrep -u "$UID" -x polybar >/dev/null; do
    sleep 0.2
done

BATTERY=$(ls /sys/class/power_supply/ | grep -E '^BAT' | head -n1)
ADAPTER=$(ls /sys/class/power_supply/ | grep -E '^(AC|ACAD|ADP)' | head -n1)

# Fallback
BATTERY=${BATTERY:-BAT1}
ADAPTER=${ADAPTER:-AC}

export BATTERY
export ADAPTER

if type xrandr >/dev/null 2>&1; then
    MON_PRIMARY=$(xrandr --query | awk '/ connected primary / {print $1; exit}')

    MON_SECONDARY=$(
        xrandr --listactivemonitors |
        awk 'NR > 1 {print $NF}' |
        grep -vx "$MON_PRIMARY" |
        head -n1
    )

    MONITOR="$MON_PRIMARY" polybar --reload bar_top &
    MONITOR="$MON_PRIMARY" polybar --reload bar_bottom &

    if [ -n "$MON_SECONDARY" ]; then
        MONITOR="$MON_SECONDARY" polybar --reload bar_top &
        MONITOR="$MON_SECONDARY" polybar --reload bar_bottom &
    fi
else
    polybar --reload bar_top &
    polybar --reload bar_bottom &
fi

echo "Polybar launched..."
