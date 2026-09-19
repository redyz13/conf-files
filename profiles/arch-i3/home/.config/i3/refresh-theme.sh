#!/usr/bin/env bash

ACTIVE_DIR="$HOME/Wallpapers/active"
WAL_DIR="$HOME/.cache/wal"
STARTUP_WALLPAPER_FILE="${XDG_RUNTIME_DIR:-/tmp}/archlain-startup-wallpaper"

CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/archlain/theme-cache"
BUNDLES_DIR="$CACHE_ROOT/bundles"

BUILD_CACHE="$HOME/.config/i3/build-theme-cache.sh"
POLYBAR_LAUNCH="$HOME/.config/polybar/launch.sh"
DUNST_LAUNCH="$HOME/.config/dunst/launch.sh"
NVIM_RELOAD="$HOME/.config/i3/reload-colors-nvim.sh"

prepare_startup_wallpaper() {
    local requested="${1:-}"
    local selected=""
    local current

    if [[ -n "$requested" ]]; then
        selected="$(realpath -e "$requested")" || return 1
    else
        current="$(cat "$WAL_DIR/wal" 2>/dev/null)"

        while IFS= read -r -d '' selected; do
            [[ "$selected" == "$current" ]] && continue
            break
        done < <(
            find "$ACTIVE_DIR" -maxdepth 1 -type f -print0 |
                shuf -z
        )

        selected="$(realpath -e "$selected")" || return 1
    fi

    case "$selected" in
        "$ACTIVE_DIR"/*)
            ;;
        *)
            return 1
            ;;
    esac

    [[ -f "$selected" ]] || return 1

    printf '%s\n' "$selected" > "$STARTUP_WALLPAPER_FILE"
    printf '%s\n' "$selected"
}

if [[ "${1:-}" == "--prepare-startup" ]]; then
    prepare_startup_wallpaper "${2:-}"
    exit $?
fi

lock="${XDG_RUNTIME_DIR:-/tmp}/refresh-theme.lock"
exec 9>"$lock" || exit 1
flock -n 9 || exit 0

required_files=(
    colors
    colors.Xresources
    colors.sh
    colors.json
    colors-wal.vim
    colors-rofi-dark.rasi
    colors-tty.sh
    sequences
    wal
)

if command -v pacman >/dev/null 2>&1; then
    PYWAL_VERSION="$(pacman -Q python-pywal 2>/dev/null || wal -v)"
else
    PYWAL_VERSION="$(wal -v)"
fi

if [[ -d "$HOME/.config/wal" ]]; then
    WAL_CONFIG_HASH="$(
        find "$HOME/.config/wal" -type f -print0 |
            sort -z |
            xargs -0 -r sha256sum |
            sha256sum |
            awk '{print $1}'
    )"
else
    WAL_CONFIG_HASH="$(
        printf '%s' 'no-wal-config' |
            sha256sum |
            awk '{print $1}'
    )"
fi

bundle_path() {
    local wallpaper="$1"
    local key

    key="$(
        printf '%s' "$wallpaper" |
            sha256sum |
            awk '{print $1}'
    )"

    printf '%s\n' "$BUNDLES_DIR/$key"
}

bundle_valid() {
    local wallpaper="$1"
    local bundle="$2"
    local manifest="$bundle/manifest"
    local image_size
    local image_mtime
    local file

    [[ -f "$manifest" ]] || return 1

    read -r image_size image_mtime < <(
        stat -c '%s %Y' "$wallpaper"
    ) || return 1

    grep -Fqx "wallpaper=$wallpaper" "$manifest" || return 1
    grep -Fqx "image_size=$image_size" "$manifest" || return 1
    grep -Fqx "image_mtime=$image_mtime" "$manifest" || return 1
    grep -Fqx "pywal_version=$PYWAL_VERSION" "$manifest" || return 1
    grep -Fqx "wal_config_hash=$WAL_CONFIG_HASH" "$manifest" || return 1

    for file in "${required_files[@]}"; do
        [[ -f "$bundle/files/$file" ]] || return 1
    done
}

ensure_bundle() {
    local wallpaper="$1"
    local bundle

    bundle="$(bundle_path "$wallpaper")"

    if ! bundle_valid "$wallpaper" "$bundle"; then
        "$BUILD_CACHE" "$wallpaper" >/dev/null 2>&1 || return 1
        bundle_valid "$wallpaper" "$bundle" || return 1
    fi

    printf '%s\n' "$bundle"
}

refresh_terminals() {
    local terminal

    [[ -f "$WAL_DIR/sequences" ]] || return 0

    for terminal in /dev/pts/[0-9]*; do
        [[ -w "$terminal" ]] || continue
        cat "$WAL_DIR/sequences" > "$terminal" 2>/dev/null || true
    done
}

apply_theme() {
    local wallpaper
    local bundle
    local wallpaper_pid
    local polybar_pid
    local i3_pid
    local dunst_pid=""

    wallpaper="$(realpath -e "$1")" || return 1

    case "$wallpaper" in
        "$ACTIVE_DIR"/*)
            ;;
        *)
            return 1
            ;;
    esac

    [[ -f "$wallpaper" ]] || return 1

    bundle="$(ensure_bundle "$wallpaper")" || return 1

    mkdir -p "$WAL_DIR"

    cp -a "$bundle/files/." "$WAL_DIR/" || return 1
    xrdb -merge -quiet "$WAL_DIR/colors.Xresources" || return 1

    feh --no-fehbg --bg-fill "$wallpaper" >/dev/null 2>&1 9>&- &
    wallpaper_pid=$!

    "$NVIM_RELOAD" >/dev/null 2>&1 9>&- || true

    refresh_terminals

    "$POLYBAR_LAUNCH" --replace 9>&- &
    polybar_pid=$!

    i3-msg reload >/dev/null 2>&1 9>&- &
    i3_pid=$!

    if pgrep -x dunst >/dev/null; then
        "$DUNST_LAUNCH" >/dev/null 2>&1 9>&- &
        dunst_pid=$!
    fi

    if ! wait "$polybar_pid"; then
        "$POLYBAR_LAUNCH" 9>&- || return 1
    fi

    wait "$wallpaper_pid" 2>/dev/null || true
    wait "$i3_pid" 2>/dev/null || true

    if [[ -n "$dunst_pid" ]]; then
        wait "$dunst_pid" 2>/dev/null || true
    fi
}

if [[ "${1:-}" == "--startup" ]]; then
    startup_wallpaper="$(
        cat "$STARTUP_WALLPAPER_FILE" 2>/dev/null
    )" || exit 1

    apply_theme "$startup_wallpaper"
    exit $?
fi

current="$(cat "$WAL_DIR/wal" 2>/dev/null)"

if [[ -n "${1:-}" ]]; then
    apply_theme "$1"
    exit $?
fi

while IFS= read -r -d '' wallpaper; do
    [[ "$wallpaper" == "$current" ]] && continue

    if apply_theme "$wallpaper"; then
        exit 0
    fi
done < <(
    find "$ACTIVE_DIR" -maxdepth 1 -type f -print0 |
        shuf -z
)

exit 1
