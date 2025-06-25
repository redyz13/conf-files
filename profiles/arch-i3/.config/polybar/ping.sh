#!/bin/bash
echo "...   "
while true; do
    ping -c 1 -W 1 1.1.1.1 2>/dev/null | awk -F'time=' '
    /time=/ {
        split($2, a, " ")
        printf("%d ms\n", a[1])
    }
    END {
        if (NR == 0) print "no conn"
    }'
    sleep 2
done

