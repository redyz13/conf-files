#!/bin/bash

CONFIG_FILE="/etc/X11/xorg.conf.d/99-controller-touchpad-ignore.conf"

get_ids() {
    xinput list |
        grep -E "Controller Touchpad" |
        grep -o 'id=[0-9]*' |
        cut -d= -f2
}

if [[ -e "$CONFIG_FILE" ]]; then
    sudo rm "$CONFIG_FILE" || exit 1

    while IFS= read -r id; do
        [[ -n "$id" ]] && xinput enable "$id" 2>/dev/null || true
    done < <(get_ids)

    echo "Controller touchpads enabled"
    echo "Restart X to fully apply"
else
    sudo mkdir -p /etc/X11/xorg.conf.d || exit 1

    sudo tee "$CONFIG_FILE" > /dev/null <<EOF
Section "InputClass"
    Identifier "Ignore controller touchpads"
    MatchProduct "Controller Touchpad"
    MatchIsTouchpad "on"
    Option "Ignore" "true"
EndSection
EOF

    while IFS= read -r id; do
        [[ -n "$id" ]] && xinput disable "$id" 2>/dev/null || true
    done < <(get_ids)

    echo "Controller touchpads disabled"
    echo "Restart X to fully apply"
fi
