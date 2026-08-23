#!/usr/bin/env bash

set -euo pipefail

INTERNAL="eDP-1"
TV="HDMI-1"

TV_MODE="1920x1080"
TV_RATE="60"

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/tv-mode"
DISPLAY_STATE="$STATE_DIR/displays.json"
WORKSPACE_STATE="$STATE_DIR/workspaces.json"
ACTIVE_STATE="$STATE_DIR/active"

notify() {
    notify-send "TV Mode" "$1" || true
}

restart_polybar() {
    timeout 3s "$HOME/.config/polybar/launch.sh" >/dev/null 2>&1 || true
}

capture_displays() {
    python3 - "$DISPLAY_STATE" "$INTERNAL" "$TV" <<'PY'
import json
import re
import subprocess
import sys

outfile, internal, tv = sys.argv[1:]
wanted = {internal, tv}

text = subprocess.check_output(
    ["xrandr", "--query"],
    text=True,
)

state = {}
current = None

for line in text.splitlines():
    if line and not line[0].isspace():
        current = None

        match = re.match(
            r'^(\S+)\s+(connected|disconnected)(.*)$',
            line,
        )

        if not match:
            continue

        name, status, rest = match.groups()

        if name not in wanted:
            continue

        entry = {
            "connected": status == "connected",
            "active": False,
            "mode": None,
            "rate": None,
            "x": None,
            "y": None,
            "primary": False,
        }

        if status == "connected":
            geometry = re.search(
                r'\s(\d+x\d+)([+-]\d+)([+-]\d+)(?:\s|\()',
                rest,
            )

            if geometry:
                entry["active"] = True
                entry["mode"] = geometry.group(1)
                entry["x"] = int(geometry.group(2))
                entry["y"] = int(geometry.group(3))

            entry["primary"] = bool(
                re.search(r'(^|\s)primary(\s|$)', rest)
            )

        state[name] = entry
        current = name
        continue

    if current in state and state[current]["active"]:
        mode_line = re.match(
            r'^\s+(\S+)\s+(.*)$',
            line,
        )

        if not mode_line:
            continue

        mode, rates = mode_line.groups()

        current_rate = re.search(
            r'([0-9]+(?:\.[0-9]+)?)\*',
            rates,
        )

        if current_rate:
            state[current]["mode"] = mode
            state[current]["rate"] = current_rate.group(1)

for name in wanted:
    if name not in state:
        raise SystemExit(f"Output {name} not found")

if not state[tv]["connected"]:
    raise SystemExit(f"{tv} is not connected")

with open(outfile, "w") as f:
    json.dump(state, f, indent=2)
PY
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

restore_displays() {
    python3 - "$DISPLAY_STATE" "$INTERNAL" "$TV" <<'PY'
import json
import subprocess
import sys

statefile = sys.argv[1]
outputs = sys.argv[2:]

with open(statefile) as f:
    state = json.load(f)

args = ["xrandr"]

for name in outputs:
    data = state[name]

    args += ["--output", name]

    if not data["active"]:
        args += ["--off"]
        continue

    args += [
        "--mode", data["mode"],
        "--rate", str(data["rate"]),
        "--pos", f'{data["x"]}x{data["y"]}',
    ]

    if data["primary"]:
        args += ["--primary"]

subprocess.check_call(args)
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


# Restore every workspace to its original output.
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


# Restore which workspace was visible on each output.
for workspace in visible:
    name = quote(workspace)

    subprocess.check_call(
        ["i3-msg", f'workspace "{name}"'],
        stdout=subprocess.DEVNULL,
    )


# Restore the originally focused workspace.
if focused is not None:
    name = quote(focused)

    subprocess.check_call(
        ["i3-msg", f'workspace "{name}"'],
        stdout=subprocess.DEVNULL,
    )
PY
}

rollback_enable() {
    local display_ok=0
    local workspace_ok=0

    if restore_displays; then
        display_ok=1
        sleep 0.4

        if restore_workspaces; then
            workspace_ok=1
        fi
    fi

    restart_polybar

    if [[ "$display_ok" -eq 1 && "$workspace_ok" -eq 1 ]]; then
        rm -rf "$STATE_DIR"
        notify "Could not enable TV Mode · Previous state restored"
    else
        notify "TV Mode failed · State kept for recovery"
    fi
}

enable_tv_mode() {
    #
    # Any leftover directory without ACTIVE is from an incomplete
    # capture before the display topology was changed and is safe
    # to replace.
    #
    rm -rf "$STATE_DIR"
    mkdir -p "$STATE_DIR"

    if ! capture_displays; then
        rm -rf "$STATE_DIR"
        notify "Could not save display state"
        exit 1
    fi

    if ! capture_workspaces; then
        rm -rf "$STATE_DIR"
        notify "Could not save workspace state"
        exit 1
    fi

    #
    # IMPORTANT:
    # Mark TV Mode active BEFORE touching the displays.
    # From here on, another invocation will always attempt restore.
    #
    touch "$ACTIVE_STATE"

    if ! xrandr \
        --output "$TV" \
        --mode "$TV_MODE" \
        --rate "$TV_RATE" \
        --primary \
        --pos 0x0 \
        --output "$INTERNAL" \
        --off
    then
        rollback_enable
        exit 1
    fi

    sleep 0.4
    restart_polybar

    notify "ON · Internal display off"
}

disable_tv_mode() {
    if [[ ! -f "$ACTIVE_STATE" ||
          ! -f "$DISPLAY_STATE" ||
          ! -f "$WORKSPACE_STATE" ]]; then
        notify "Saved TV Mode state is incomplete"
        exit 1
    fi

    if ! restore_displays; then
        restart_polybar
        notify "Could not restore displays · State kept for retry"
        exit 1
    fi

    sleep 0.4

    if ! restore_workspaces; then
        restart_polybar
        notify "Displays restored · Workspace state kept for retry"
        exit 1
    fi

    restart_polybar

    #
    # Recovery data is removed only after the complete restore.
    #
    rm -rf "$STATE_DIR"

    notify "OFF · Previous state restored"
}

if [[ -f "$ACTIVE_STATE" ]]; then
    disable_tv_mode
else
    enable_tv_mode
fi
