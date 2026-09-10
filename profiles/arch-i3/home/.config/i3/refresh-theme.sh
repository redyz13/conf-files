#!/bin/bash

lock="${XDG_RUNTIME_DIR:-/tmp}/refresh-theme.lock"
exec 9>"$lock" || exit 1
flock -n 9 || exit 0

current="$(cat "$HOME/.cache/wal/wal" 2>/dev/null)"

apply_theme() {
    local wallpaper="$1"

    if wal -q -i "$wallpaper" >/dev/null 2>&1; then
        "$HOME/.config/i3/reload-colors-nvim.sh"
        return 0
    fi

    if wal -q --backend colorthief -i "$wallpaper" >/dev/null 2>&1; then
        "$HOME/.config/i3/reload-colors-nvim.sh"
        return 0
    fi

    return 1
}

if [[ -n "$1" ]]; then
    if ! apply_theme "$1"; then
        [[ -n "$current" ]] && printf '%s\n' "$current" > "$HOME/.cache/wal/wal"
        exit 1
    fi

    exit 0
fi

while IFS= read -r -d '' wallpaper; do
    [[ "$wallpaper" == "$current" ]] && continue

    if apply_theme "$wallpaper"; then
        exit 0
    fi
done < <(find "$HOME/Wallpapers" -type f -print0 | shuf -z)

[[ -n "$current" ]] && printf '%s\n' "$current" > "$HOME/.cache/wal/wal"
exit 1
