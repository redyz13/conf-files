#!/bin/bash

SESSION=$(tmux new-session -dP)

tmux set-hook -t "$SESSION" client-detached "if -F '#{session_attached}' '' 'kill-session -t $SESSION'"

tmux attach-session -t "$SESSION"

