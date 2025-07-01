#!/bin/bash
while true; do
    id=$(xinput list | grep "Wireless Controller Touchpad" | awk '{print $6}' | cut -d'=' -f2)
    if [[ -n "$id" ]]; then
        xinput disable "$id"
    fi
    sleep 10
done

