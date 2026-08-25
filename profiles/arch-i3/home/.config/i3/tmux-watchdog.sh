#!/bin/bash

while true; do
    for session in $(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep '_temp$'); do
        attached=$(tmux list-clients -t "$session" 2>/dev/null | wc -l)
        if [ "$attached" -eq 0 ]; then
            tmux kill-session -t "$session"
        fi
    done
    sleep 10
done

