
#!/usr/bin/env bash
set -euo pipefail

MOUSE_NAME="${1:-}"
MODE="${2:-toggle}"
CONFIG_FILE="/etc/X11/xorg.conf.d/90-mouse-accel.conf"
PROPERTY="libinput Accel Profile Enabled"

if [[ -z "$MOUSE_NAME" || $# -gt 2 ]]; then
    echo "Usage: $0 \"Exact Mouse Name\" [flat|adaptive|toggle]"
    exit 1
fi

case "$MODE" in
    flat|adaptive|toggle) ;;
    *)
        echo "Invalid mode: $MODE"
        exit 1
        ;;
esac

DEVICE_ID=$(xinput list --id-only "$MOUSE_NAME" 2>/dev/null || true)

if [[ ! "$DEVICE_ID" =~ ^[0-9]+$ ]]; then
    echo "Mouse not found or ambiguous: $MOUSE_NAME"
    exit 1
fi

DEVICE_NAME=$(xinput list --name-only "$DEVICE_ID")

if [[ "$DEVICE_NAME" != "$MOUSE_NAME" ]]; then
    echo "Mouse name does not match exactly: $DEVICE_NAME"
    exit 1
fi

PROPERTY_LINE=$(xinput list-props "$DEVICE_ID" | grep -F "$PROPERTY (" || true)

if [[ -z "$PROPERTY_LINE" ]]; then
    echo "Acceleration profile not supported."
    exit 1
fi

VALUES="${PROPERTY_LINE#*:}"
read -r -a CURRENT <<< "${VALUES//,/ }"

if [[ ${#CURRENT[@]} -ne 2 && ${#CURRENT[@]} -ne 3 ]]; then
    echo "Unsupported acceleration profile format."
    exit 1
fi

if [[ "$MODE" == "toggle" ]]; then
    if [[ "${CURRENT[1]}" == "1" ]]; then
        MODE="adaptive"
    else
        MODE="flat"
    fi
fi

if [[ "$MODE" == "flat" ]]; then
    TARGET=(0 1)
else
    TARGET=(1 0)
fi

if [[ ${#CURRENT[@]} -eq 3 ]]; then
    TARGET+=(0)
fi

if sudo test -e "$CONFIG_FILE"; then
    if ! sudo grep -Fq 'Identifier "Mouse Accel Toggle"' "$CONFIG_FILE"; then
        echo "Refusing to overwrite an unrelated configuration."
        exit 1
    fi
fi

TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT

cat > "$TMP_FILE" <<EOF
Section "InputClass"
    Identifier "Mouse Accel Toggle"
    MatchProduct "$MOUSE_NAME"
    Driver "libinput"
    Option "AccelProfile" "$MODE"
EndSection
EOF

sudo -v

if ! xinput set-prop "$DEVICE_ID" "$PROPERTY" "${TARGET[@]}"; then
    echo "Failed to apply acceleration profile."
    exit 1
fi

sudo install -m 644 "$TMP_FILE" "$CONFIG_FILE"

echo "Mouse: $MOUSE_NAME"
echo "Acceleration: $MODE (persisted)"

