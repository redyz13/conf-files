#!/usr/bin/env bash

set -euo pipefail

DISPLAY_APPLY="$HOME/.config/i3/display_apply.sh"

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/tv-mode"
WORKSPACE_STATE="$STATE_DIR/workspaces.json"
PREVIOUS_MODE="$STATE_DIR/previous-mode"
ACTIVE_STATE="$STATE_DIR/active"

MODE_STATE="${XDG_RUNTIME_DIR:-/tmp}/display-mode/current"

REQUESTED_MODE="${1:-toggle}"

notify() {
    notify-send "TV Mode" "$1" || true
}

capture_workspaces() {
    i3-msg -t get_workspaces > "$WORKSPACE_STATE"

    python3 - "$WORKSPACE_STATE" <<'PY'
import json
import sys

with open(sys.argv[1]) as f:
    json.load(f)
PY
}

restore_workspaces() {
    python3 - "$WORKSPACE_STATE" <<'PY'
import json
import subprocess
import sys

with open(sys.argv[1]) as f:
    workspaces = json.load(f)

outputs = json.loads(
    subprocess.check_output(
        ["i3-msg", "-t", "get_outputs"],
        text=True,
    )
)

active_outputs = [output for output in outputs if output.get("active")]

if not active_outputs:
    raise SystemExit("No active i3 outputs")

active_names = {output["name"] for output in active_outputs}

fallback = next(
    (
        output["name"]
        for output in active_outputs
        if output.get("primary")
    ),
    active_outputs[0]["name"],
)

focused = None
visible = []

def quote(value):
    return str(value).replace("\\", "\\\\").replace('"', '\\"')

for workspace in workspaces:
    name = workspace["name"]
    output = workspace["output"]

    if output not in active_names:
        output = fallback

    subprocess.check_call(
        [
            "i3-msg",
            f'workspace "{quote(name)}"; '
            f'move workspace to output "{quote(output)}"',
        ],
        stdout=subprocess.DEVNULL,
    )

    if workspace["visible"]:
        visible.append(name)

    if workspace["focused"]:
        focused = name

for workspace in visible:
    subprocess.check_call(
        ["i3-msg", f'workspace "{quote(workspace)}"'],
        stdout=subprocess.DEVNULL,
    )

if focused is not None:
    subprocess.check_call(
        ["i3-msg", f'workspace "{quote(focused)}"'],
        stdout=subprocess.DEVNULL,
    )
PY
}

get_previous_mode() {
    local mode="auto"

    if [[ -f "$MODE_STATE" ]]; then
        mode="$(<"$MODE_STATE")"
    fi

    case "$mode" in
        auto|left|right|mirror)
            printf '%s\n' "$mode"
            ;;
        *)
            printf '%s\n' auto
            ;;
    esac
}

rollback_enable() {
    local mode

    mode="$(<"$PREVIOUS_MODE")"

    "$DISPLAY_APPLY" "$mode" >/dev/null 2>&1 || true
    sleep 0.2
    restore_workspaces >/dev/null 2>&1 || true

    rm -rf "$STATE_DIR"

    notify "Could not enable TV Mode · Previous state restored"
}

enable_tv_mode() {
    rm -rf "$STATE_DIR"
    mkdir -p "$STATE_DIR"

    get_previous_mode > "$PREVIOUS_MODE"

    if ! capture_workspaces; then
        rm -rf "$STATE_DIR"
        notify "Could not save workspace state"
        exit 1
    fi

    touch "$ACTIVE_STATE"

    if ! "$DISPLAY_APPLY" external; then
        rollback_enable
        exit 1
    fi

    notify "ON · External display only"
}

restore_tv_state() {
    local mode="$1"

    if [[ ! -f "$WORKSPACE_STATE" ]]; then
        notify "Saved TV Mode state is incomplete"
        return 1
    fi

    if ! "$DISPLAY_APPLY" "$mode"; then
        notify "Could not restore display layout · State kept for retry"
        return 1
    fi

    sleep 0.2

    if ! restore_workspaces; then
        notify "Display restored · Workspace state kept for retry"
        return 1
    fi

    rm -rf "$STATE_DIR"
}

disable_tv_mode() {
    if [[ ! -f "$PREVIOUS_MODE" ]]; then
        notify "Saved TV Mode state is incomplete"
        exit 1
    fi

    local mode
    mode="$(<"$PREVIOUS_MODE")"

    if ! restore_tv_state "$mode"; then
        exit 1
    fi

    notify "OFF · Previous state restored"
}

apply_requested_mode() {
    local mode="$1"

    if [[ -f "$ACTIVE_STATE" ]]; then
        if ! restore_tv_state "$mode"; then
            exit 1
        fi

        notify "OFF · Workspace state restored"
        return
    fi

    "$DISPLAY_APPLY" "$mode"
}

case "$REQUESTED_MODE" in
    toggle)
        if [[ -f "$ACTIVE_STATE" ]]; then
            disable_tv_mode
        else
            enable_tv_mode
        fi
        ;;

    auto|left|right|mirror)
        apply_requested_mode "$REQUESTED_MODE"
        ;;

    *)
        echo "Usage: $0 [auto|left|right|mirror]" >&2
        exit 2
        ;;
esac
