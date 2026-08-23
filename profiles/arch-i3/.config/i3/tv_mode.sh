#!/usr/bin/env bash

set -euo pipefail

DISPLAY_APPLY="$HOME/.config/i3/display_apply.sh"

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/tv-mode"
WORKSPACE_STATE="$STATE_DIR/workspaces.json"
PREVIOUS_MODE="$STATE_DIR/previous-mode"
ACTIVE_STATE="$STATE_DIR/active"

MODE_STATE="${XDG_RUNTIME_DIR:-/tmp}/display-mode/current"

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

focused = None
visible = []

def quote(value):
    return str(value).replace("\\", "\\\\").replace('"', '\\"')

for workspace in workspaces:
    name = quote(workspace["name"])
    output = quote(workspace["output"])

    subprocess.check_call(
        [
            "i3-msg",
            f'workspace "{name}"; move workspace to output "{output}"',
        ],
        stdout=subprocess.DEVNULL,
    )

    if workspace["visible"]:
        visible.append(workspace["name"])

    if workspace["focused"]:
        focused = workspace["name"]

for workspace in visible:
    name = quote(workspace)

    subprocess.check_call(
        ["i3-msg", f'workspace "{name}"'],
        stdout=subprocess.DEVNULL,
    )

if focused is not None:
    name = quote(focused)

    subprocess.check_call(
        ["i3-msg", f'workspace "{name}"'],
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

    # From this point another invocation always attempts recovery.
    touch "$ACTIVE_STATE"

    if ! "$DISPLAY_APPLY" external; then
        rollback_enable
        exit 1
    fi

    notify "ON · External display only"
}

disable_tv_mode() {
    if [[ ! -f "$PREVIOUS_MODE" || ! -f "$WORKSPACE_STATE" ]]; then
        notify "Saved TV Mode state is incomplete"
        exit 1
    fi

    local mode
    mode="$(<"$PREVIOUS_MODE")"

    if ! "$DISPLAY_APPLY" "$mode"; then
        notify "Could not restore display layout · State kept for retry"
        exit 1
    fi

    sleep 0.2

    if ! restore_workspaces; then
        notify "Display restored · Workspace state kept for retry"
        exit 1
    fi

    rm -rf "$STATE_DIR"

    notify "OFF · Previous state restored"
}

if [[ -f "$ACTIVE_STATE" ]]; then
    disable_tv_mode
else
    enable_tv_mode
fi
