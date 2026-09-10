#!/bin/bash

lock="${XDG_RUNTIME_DIR:-/tmp}/refresh-theme.lock"
exec 9>"$lock" || exit 1
flock -n 9 || exit 0

current="$(cat "$HOME/.cache/wal/wal" 2>/dev/null)"

apply_theme() {
    local wallpaper="$1"

    wal -q -e -i "$wallpaper" >/dev/null 2>&1 || return 1

    xrdb -merge -quiet "$HOME/.cache/wal/colors.Xresources"
    i3-msg reload >/dev/null

    while read -r pid; do
        polybar-msg -p "$pid" cmd restart >/dev/null 2>&1
    done < <(pgrep -x polybar)

    "$HOME/.config/i3/reload-colors-nvim.sh"

    # Keep the lock while Polybar completes its internal restart.
    sleep 0.35
}

if [[ -n "$1" ]]; then
    apply_theme "$1"
    exit $?
fi

while IFS= read -r -d '' wallpaper; do
    [[ "$wallpaper" == "$current" ]] && continue

    if apply_theme "$wallpaper"; then
        exit 0
    fi
done < <(
    find "$HOME/Wallpapers/active" -maxdepth 1 -type f -print0 |
        shuf -z
)

exit 1
