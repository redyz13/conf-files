#!/bin/bash

if pgrep -xu "$EUID" -x i3lock >/dev/null; then
  exit 0
fi

source "$HOME/.cache/wal/colors.sh"

i3lock_options=(
  --color="${background:1}"
  --time-font="Hack Nerd Font"
  --date-font="Hack Nerd Font"
  --verif-font="Hack Nerd Font"
  --wrong-font="Hack Nerd Font"
  --blur=5
  --clock
  --indicator
  --ring-width=8
  --radius=130
  --ring-color="${color4:1}aa"
  --inside-color="00000088"
  --line-color="00000000"
  --separator-color="00000000"
  --keyhl-color="${color5:1}cc"
  --bshl-color="${color1:1}cc"
  --insidever-color="00000088"
  --ringver-color="${color2:1}cc"
  --insidewrong-color="00000088"
  --ringwrong-color="${color1:1}cc"
  --verif-color="${foreground:1}aa"
  --wrong-color="${foreground:1}aa"
  --time-color="${foreground:1}ff"
  --date-color="${foreground:1}cc"
  --layout-color="${foreground:1}aa"
  --greeter-color="${foreground:1}aa"
  --time-str="%H:%M:%S"
  --date-str="%A, %d %B"
  --noinput-text=""
  --wrong-text=""
  --verif-text=""
)

dpms_watchdog() {
  local idle_ms
  local screen_off=0

  while pgrep -xu "$EUID" -x i3lock >/dev/null; do
    idle_ms=$(xssstate -i 2>/dev/null) || return

    if [[ "$idle_ms" =~ ^[0-9]+$ ]]; then
      if (( idle_ms >= 15000 )); then
        if (( screen_off == 0 )); then
          xset dpms force off
          screen_off=1
        fi
      else
        screen_off=0
      fi
    fi

    sleep 1
  done
}

if [[ -e /dev/fd/${XSS_SLEEP_LOCK_FD:--1} ]]; then
  kill_i3lock() {
    pkill -xu "$EUID" "$@" i3lock
  }

  trap kill_i3lock TERM INT

  i3lock "${i3lock_options[@]}" {XSS_SLEEP_LOCK_FD}<&-

  exec {XSS_SLEEP_LOCK_FD}<&-

  dpms_watchdog &

  while kill_i3lock -0; do
    sleep 0.5
  done
else
  i3lock --nofork "${i3lock_options[@]}" &
  locker_pid=$!

  trap 'kill "$locker_pid" 2>/dev/null' TERM INT

  dpms_watchdog &

  wait "$locker_pid"
fi
