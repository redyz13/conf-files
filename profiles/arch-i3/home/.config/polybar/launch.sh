#!/usr/bin/env bash

LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/polybar"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/polybar.log"
: > "$LOG_FILE"
exec </dev/null >>"$LOG_FILE" 2>&1

stop_bars() {
    local -a old_pids=()
    local -a child_pids=()

    mapfile -t old_pids < <(pgrep -u "$UID" -x polybar)

    if ((${#old_pids[@]} == 0)); then
        return 0
    fi

    for pid in "${old_pids[@]}"; do
        while read -r child_pid; do
            [[ -n "$child_pid" ]] && child_pids+=("$child_pid")
        done < <(pgrep -P "$pid" 2>/dev/null || true)
    done

    kill -TERM "${old_pids[@]}" 2>/dev/null || true

    for _ in {1..200}; do
        alive=0

        for pid in "${old_pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                alive=1
                break
            fi
        done

        [[ "$alive" -eq 0 ]] && break
        sleep 0.01
    done

    for pid in "${old_pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null &&
           [[ "$(cat "/proc/$pid/comm" 2>/dev/null)" == "polybar" ]]; then
            kill -KILL "$pid" 2>/dev/null || true
        fi
    done

    if ((${#child_pids[@]} > 0)); then
        for _ in {1..100}; do
            alive=0

            for pid in "${child_pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    alive=1
                    break
                fi
            done

            [[ "$alive" -eq 0 ]] && return 0
            sleep 0.01
        done

        kill -TERM "${child_pids[@]}" 2>/dev/null || true

        for _ in {1..100}; do
            alive=0

            for pid in "${child_pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    alive=1
                    break
                fi
            done

            [[ "$alive" -eq 0 ]] && return 0
            sleep 0.01
        done

        kill -KILL "${child_pids[@]}" 2>/dev/null || true
    fi

    return 0
}

replace_bars() {
    if ! command -v xdotool >/dev/null 2>&1; then
        return 1
    fi

    mapfile -t old_pids < <(pgrep -u "$UID" -x polybar)

    if ((${#old_pids[@]} == 0)); then
        return 1
    fi

    local -a new_pids=()
    local -a was_visible=()

    for old_pid in "${old_pids[@]}"; do
        if [[ ! -r "/proc/$old_pid/environ" || ! -r "/proc/$old_pid/cmdline" ]]; then
            kill -9 "${new_pids[@]}" 2>/dev/null || true
            return 1
        fi

        if xdotool search --onlyvisible --pid "$old_pid" >/dev/null 2>&1; then
            was_visible+=(1)
        else
            was_visible+=(0)
        fi

        bar="$(
            tr '\0' '\n' < "/proc/$old_pid/cmdline" |
                tail -n1
        )"

        case "$bar" in
            bar_top|bar_bottom)
                ;;
            *)
                kill -9 "${new_pids[@]}" 2>/dev/null || true
                return 1
                ;;
        esac

        (
            while IFS= read -r -d '' entry; do
                export "$entry"
            done < "/proc/$old_pid/environ"

            exec polybar --reload "$bar"
        ) &

        new_pids+=("$!")
    done

    for i in "${!new_pids[@]}"; do
        new_pid="${new_pids[$i]}"
        mapped=0

        for _ in {1..400}; do
            if ! kill -0 "$new_pid" 2>/dev/null; then
                break
            fi

            if xdotool search --onlyvisible --pid "$new_pid" >/dev/null 2>&1; then
                mapped=1
                break
            fi

            sleep 0.005
        done

        if [[ "$mapped" -ne 1 ]]; then
            kill -9 "${new_pids[@]}" 2>/dev/null || true
            return 1
        fi

        if [[ "${was_visible[$i]}" -eq 0 ]]; then
            polybar-msg -p "$new_pid" cmd hide >/dev/null 2>&1

            hidden=0

            for _ in {1..100}; do
                if ! xdotool search --onlyvisible --pid "$new_pid" >/dev/null 2>&1; then
                    hidden=1
                    break
                fi

                sleep 0.002
            done

            if [[ "$hidden" -ne 1 ]]; then
                kill -9 "${new_pids[@]}" 2>/dev/null || true
                return 1
            fi
        fi
    done

    local -a hide_jobs=()

    for i in "${!old_pids[@]}"; do
        if [[ "${was_visible[$i]}" -eq 1 ]]; then
            polybar-msg -p "${old_pids[$i]}" cmd hide >/dev/null 2>&1 &
            hide_jobs+=("$!")
        fi
    done

    for job in "${hide_jobs[@]}"; do
        wait "$job" 2>/dev/null || true
    done

    kill -TERM "${old_pids[@]}" 2>/dev/null || true

    for _ in {1..200}; do
        alive=0

        for pid in "${old_pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                alive=1
                break
            fi
        done

        [[ "$alive" -eq 0 ]] && return 0

        sleep 0.01
    done

    for pid in "${old_pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null &&
           [[ "$(cat "/proc/$pid/comm" 2>/dev/null)" == "polybar" ]]; then
            kill -KILL "$pid" 2>/dev/null || true
        fi
    done
}

case "${1:-}" in
    --replace)
        replace_bars
        exit $?
        ;;

    --stop)
        stop_bars
        exit $?
        ;;
esac

stop_bars

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
