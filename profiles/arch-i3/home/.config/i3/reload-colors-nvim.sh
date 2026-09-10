#!/bin/bash

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

for socket in "$runtime_dir"/nvim.*.0; do
    [[ -S "$socket" ]] || continue

    nvim --server "$socket" \
        --remote-expr 'execute("colorscheme pywal16")' \
        >/dev/null 2>&1 &
done

wait
