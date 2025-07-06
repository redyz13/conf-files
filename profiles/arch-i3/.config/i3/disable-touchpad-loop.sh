#!/bin/bash
while true; do
    ids=$(xinput list | grep -i "Touchpad" | grep -o 'id=[0-9]\+' | cut -d'=' -f2)
    for id in $ids; do
        xinput disable "$id"
    done
    sleep 10
done


