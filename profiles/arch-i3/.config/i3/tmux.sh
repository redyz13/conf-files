#!/bin/bash

if [[ -f "$HOME/.cache/wal/sequences" ]]; then
    cat "$HOME/.cache/wal/sequences"
fi

SESSION="session_$$"_temp

tmux new-session -d -s "$SESSION"
tmux attach-session -t "$SESSION"
