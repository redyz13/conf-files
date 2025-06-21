#!/bin/bash
tmux list-panes -a -F "#{pane_pid} #{pane_id}" | while read pid pane; do
  if pgrep -P "$pid" -x nvim > /dev/null; then
    tmux send-keys -t "$pane" ":colorscheme pywal" C-m
  fi
done

