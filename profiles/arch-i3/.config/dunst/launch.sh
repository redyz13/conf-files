#!/bin/bash
WAL_COLORS="$HOME/.cache/wal/colors"
DUNST_CONFIG="$HOME/.config/dunst/dunstrc"

if [ ! -f "$WAL_COLORS" ]; then
    exit 1
fi

mapfile -t colors < "$WAL_COLORS"

cat <<EOF > "$DUNST_CONFIG"
[global]
    background = "${colors[0]}"
    foreground = "${colors[5]}"
    frame_color = "${colors[4]}"
    separator_color = "${colors[4]}"
    font = Hack Nerd Font 12
    padding = 8
    horizontal_padding = 8
    frame_width = 2
    corner_radius = 0
    transparency = 10
    timeout = 5
    origin = top-right
    offset = (32,63)

[urgency_low]
    background = "${colors[0]}"
    foreground = "${colors[5]}"
    frame_color = "${colors[4]}"

[urgency_normal]
    background = "${colors[0]}"
    foreground = "${colors[5]}"
    frame_color = "${colors[4]}"

[urgency_critical]
    background = "${colors[1]}"
    foreground = "${colors[5]}"
    frame_color = "${colors[1]}"
EOF

pkill -x dunst 2>/dev/null || true

dunst -conf "$DUNST_CONFIG" &


