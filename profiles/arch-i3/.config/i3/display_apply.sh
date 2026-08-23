#!/usr/bin/env bash

set -euo pipefail

DPI=110
MODE="${1:-auto}"

mapfile -t CONNECTED < <(
    xrandr --query |
        awk '/^[^ ]+ connected/ { print $1 }'
)

if (( ${#CONNECTED[@]} == 0 )); then
    echo "No connected displays found." >&2
    exit 1
fi

# Prefer the laptop panel as the anchor.
# On desktops, fall back to the current primary, then the first output.
ANCHOR=""
for output in "${CONNECTED[@]}"; do
    if [[ "$output" =~ ^(eDP|LVDS|DSI) ]]; then
        ANCHOR="$output"
        break
    fi
done

if [[ -z "$ANCHOR" ]]; then
    ANCHOR="$(
        xrandr --query |
            awk '/^[^ ]+ connected primary/ { print $1; exit }'
    )"
fi

ANCHOR="${ANCHOR:-${CONNECTED[0]}}"

OTHERS=()
for output in "${CONNECTED[@]}"; do
    [[ "$output" == "$ANCHOR" ]] || OTHERS+=("$output")
done

case "$MODE" in
    auto)
        xlayoutdisplay -d "$DPI"
        ;;

    left)
        args=(-d "$DPI")

        for output in "${OTHERS[@]}"; do
            args+=(-o "$output")
        done

        args+=(-o "$ANCHOR" -p "$ANCHOR")

        xlayoutdisplay "${args[@]}"
        ;;

    right)
        args=(-d "$DPI" -o "$ANCHOR")

        for output in "${OTHERS[@]}"; do
            args+=(-o "$output")
        done

        args+=(-p "$ANCHOR")

        xlayoutdisplay "${args[@]}"
        ;;

    mirror)
        xlayoutdisplay -d "$DPI" -m
        ;;

    external)
        if [[ ! "$ANCHOR" =~ ^(eDP|LVDS|DSI) ]]; then
            echo "external mode requires an internal laptop display." >&2
            exit 1
        fi

        if (( ${#OTHERS[@]} == 0 )); then
            echo "No external display connected." >&2
            exit 1
        fi

        # Arrange external outputs first, then disable the internal panel.
        args=(-d "$DPI")

        for output in "${OTHERS[@]}"; do
            args+=(-o "$output")
        done

        args+=(-p "${OTHERS[0]}")

        xlayoutdisplay "${args[@]}"
        xrandr --output "$ANCHOR" --off
        ;;

    *)
        echo "Usage: $0 {auto|left|right|mirror|external}" >&2
        exit 2
        ;;
esac

if [[ -f "$HOME/.cache/wal/wal" ]]; then
    wallpaper="$(<"$HOME/.cache/wal/wal")"
    [[ -n "$wallpaper" ]] && feh --bg-fill "$wallpaper"
fi

"$HOME/.config/polybar/launch.sh"

MODE_STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/display-mode"
mkdir -p "$MODE_STATE_DIR"
printf '%s\n' "$MODE" > "$MODE_STATE_DIR/current"
