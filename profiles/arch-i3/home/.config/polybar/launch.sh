#!/usr/bin/env bash

killall -q polybar 2>/dev/null || true

for _ in {1..25}; do
    pgrep -u "$UID" -x polybar >/dev/null || break
    sleep 0.2
done

if pgrep -u "$UID" -x polybar >/dev/null; then
    killall -q -9 polybar
fi

BATTERY=$(ls /sys/class/power_supply/ 2>/dev/null | grep -E '^BAT' | head -n1)
ADAPTER=$(ls /sys/class/power_supply/ 2>/dev/null | grep -E '^(AC|ACAD|ADP)' | head -n1)

BATTERY=${BATTERY:-BAT1}
ADAPTER=${ADAPTER:-AC}

POLYBAR_MODULES_LEFT="pulseaudio memory cpu ping"
POLYBAR_MODULES_RIGHT="filesystem"

if command -v brightnessctl >/dev/null 2>&1 && compgen -G '/sys/class/backlight/*' >/dev/null; then
    POLYBAR_MODULES_LEFT="pulseaudio brightness memory cpu ping"
fi

if compgen -G '/sys/class/power_supply/BAT*' >/dev/null; then
    POLYBAR_MODULES_RIGHT="filesystem battery"

    if [[ -f /etc/tlp.d/99-mode.conf ]]; then
        POLYBAR_MODULES_RIGHT+=" powerdot"
    fi
fi

export BATTERY
export ADAPTER
export POLYBAR_MODULES_LEFT
export POLYBAR_MODULES_RIGHT

launch_bars() {
    local monitor="$1"

    MONITOR="$monitor" polybar --reload bar_top &
    MONITOR="$monitor" polybar --reload bar_bottom &
}

if command -v xrandr >/dev/null 2>&1; then
    mapfile -t MONITORS < <(
        xrandr --listactivemonitors |
        awk '
            NR > 1 {
                geometry = $3
                gsub(/\/[0-9]+/, "", geometry)
                print $2 "|" geometry "|" $NF
            }
        '
    )

    declare -A SEEN_GEOMETRY=()

    # Launch the primary monitor first.
    for entry in "${MONITORS[@]}"; do
        IFS='|' read -r flags geometry monitor <<< "$entry"

        if [[ "$flags" == *"*"* ]]; then
            launch_bars "$monitor"
            SEEN_GEOMETRY["$geometry"]=1
            break
        fi
    done

    # Launch one pair of bars for every other distinct desktop area.
    # Mirrored outputs share the same geometry and are therefore skipped.
    for entry in "${MONITORS[@]}"; do
        IFS='|' read -r flags geometry monitor <<< "$entry"

        [[ "$flags" == *"*"* ]] && continue

        if [[ -z "${SEEN_GEOMETRY[$geometry]+x}" ]]; then
            launch_bars "$monitor"
            SEEN_GEOMETRY["$geometry"]=1
        fi
    done
else
    polybar --reload bar_top &
    polybar --reload bar_bottom &
fi

echo "Polybar launched..."
