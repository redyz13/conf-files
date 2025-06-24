#!/bin/bash

SESSION="session_$$"_temp

tmux new-session -d -s "$SESSION"
tmux attach-session -t "$SESSION"

