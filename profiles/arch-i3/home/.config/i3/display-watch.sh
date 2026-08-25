#!/usr/bin/env bash

set -u

APPLY="$HOME/.config/i3/display_apply.sh"

connected_outputs() {
    xrandr --query |
        awk '/^[^ ]+ connected/ { print $1 }' |
        sort |
        paste -sd ',' -
}

previous="$(connected_outputs)"

udevadm monitor --udev --subsystem-match=drm --property |
while IFS= read -r line; do
    [[ "$line" == "HOTPLUG=1" ]] || continue

    # Let the kernel/X server settle after the connector event.
    sleep 0.5

    current="$(connected_outputs)"

    # Ignore RandR/modeset noise: act only when the physical
    # set of connected outputs really changed.
    [[ "$current" == "$previous" ]] && continue

    previous="$current"
    "$APPLY" auto >/dev/null 2>&1
done
