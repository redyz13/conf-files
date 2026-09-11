#!/usr/bin/env bash

set -euo pipefail

ACTIVE_DIR="$HOME/Wallpapers/active"
WAL_CONFIG_DIR="$HOME/.config/wal"
CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/archlain/theme-cache"
BUNDLES_DIR="$CACHE_ROOT/bundles"
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/build-theme-cache.lock"

exec 9>"$LOCK_FILE"
flock 9

mkdir -p "$BUNDLES_DIR"

if command -v pacman >/dev/null 2>&1; then
    PYWAL_VERSION="$(pacman -Q python-pywal 2>/dev/null || wal -v)"
else
    PYWAL_VERSION="$(wal -v)"
fi

if [[ -d "$WAL_CONFIG_DIR" ]]; then
    WAL_CONFIG_HASH="$(
        find "$WAL_CONFIG_DIR" -type f -print0 |
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

cat > "$CACHE_ROOT/environment" <<EOF
pywal_version=$PYWAL_VERSION
wal_config_hash=$WAL_CONFIG_HASH
EOF

declare -a WALLPAPERS=()

if (($# > 0)); then
    for candidate in "$@"; do
        wallpaper="$(realpath -e "$candidate")"

        case "$wallpaper" in
            "$ACTIVE_DIR"/*)
                ;;
            *)
                echo "Refusing wallpaper outside $ACTIVE_DIR: $wallpaper" >&2
                exit 1
                ;;
        esac

        [[ -f "$wallpaper" ]] || {
            echo "Not a regular file: $wallpaper" >&2
            exit 1
        }

        WALLPAPERS+=("$wallpaper")
    done
else
    mapfile -d '' WALLPAPERS < <(
        find "$ACTIVE_DIR" -maxdepth 1 -type f -print0 |
            sort -z
    )
fi

if ((${#WALLPAPERS[@]} == 0)); then
    echo "No wallpapers found in $ACTIVE_DIR" >&2
    exit 1
fi

built=0
cached=0
failed=0

declare -A WANTED=()

for wallpaper in "${WALLPAPERS[@]}"; do
    key="$(
        printf '%s' "$wallpaper" |
            sha256sum |
            awk '{print $1}'
    )"

    WANTED["$key"]=1

    image_hash="$(
        sha256sum "$wallpaper" |
            awk '{print $1}'
    )"

    read -r image_size image_mtime < <(
        stat -c '%s %Y' "$wallpaper"
    )

    bundle="$BUNDLES_DIR/$key"
    manifest="$bundle/manifest"

    if [[ -f "$manifest" ]] &&
       grep -Fqx "wallpaper=$wallpaper" "$manifest" &&
       grep -Fqx "image_sha256=$image_hash" "$manifest" &&
       grep -Fqx "image_size=$image_size" "$manifest" &&
       grep -Fqx "image_mtime=$image_mtime" "$manifest" &&
       grep -Fqx "pywal_version=$PYWAL_VERSION" "$manifest" &&
       grep -Fqx "wal_config_hash=$WAL_CONFIG_HASH" "$manifest"; then
        printf 'CACHED  %s\n' "$(basename "$wallpaper")"
        ((cached += 1))
        continue
    fi

    tmp="$(mktemp -d "$CACHE_ROOT/.build.XXXXXX")"
    render="$tmp/render"
    files="$tmp/files"
    stderr_file="$tmp/wal.stderr"

    mkdir -p "$render" "$files"

    if ! PYWAL_CACHE_DIR="$render" \
        wal -q -n -s -t -e -i "$wallpaper" \
        >/dev/null 2>"$stderr_file"; then
        printf 'FAILED  %s\n' "$(basename "$wallpaper")" >&2
        cat "$stderr_file" >&2
        rm -rf "$tmp"
        ((failed += 1))
        continue
    fi

    find "$render" \
        -maxdepth 1 \
        -type f \
        ! -name '_*.json' \
        -exec cp -a -t "$files" -- {} +

    required=(
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

    valid=1

    for file in "${required[@]}"; do
        if [[ ! -f "$files/$file" ]]; then
            echo "Missing generated artifact for $(basename "$wallpaper"): $file" >&2
            valid=0
        fi
    done

    if [[ "$valid" -ne 1 ]]; then
        rm -rf "$tmp"
        ((failed += 1))
        continue
    fi

    cat > "$tmp/manifest" <<EOF
wallpaper=$wallpaper
image_sha256=$image_hash
image_size=$image_size
image_mtime=$image_mtime
pywal_version=$PYWAL_VERSION
wal_config_hash=$WAL_CONFIG_HASH
EOF

    rm -rf "$render" "$stderr_file"

    replacement="$BUNDLES_DIR/.${key}.new"
    rm -rf "$replacement"
    mv "$tmp" "$replacement"

    rm -rf "$bundle"
    mv "$replacement" "$bundle"

    printf 'BUILT   %s\n' "$(basename "$wallpaper")"
    ((built += 1))
done

removed=0

if (($# == 0)); then
    for bundle in "$BUNDLES_DIR"/*; do
        [[ -d "$bundle" ]] || continue

        key="$(basename "$bundle")"

        if [[ -z "${WANTED[$key]+x}" ]]; then
            rm -rf "$bundle"
            ((removed += 1))
        fi
    done
fi

echo
echo "built=$built cached=$cached failed=$failed removed=$removed total=${#WALLPAPERS[@]}"

if ((failed > 0)); then
    exit 1
fi
