#!/usr/bin/env bash

choice="$(
    printf 'Cancel\nExit i3\n' |
        rofi -dmenu \
            -i \
            -no-custom \
            -p 'Exit i3?' \
            -mesg 'This will end your X session.'
)" || exit 0

if [[ "$choice" == "Exit i3" ]]; then
    i3-msg exit >/dev/null
fi
