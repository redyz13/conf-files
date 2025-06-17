#!/bin/bash

img="/tmp/screen_locked.png"
blur="/tmp/screen_locked_blur.png"

if scrot "$img"; then
  convert "$img" -blur 0x6 "$blur"
else
  cp "$HOME/.cache/wal/wall.png" "$blur" 2>/dev/null || cp "$HOME/Pictures/wall.jpg" "$blur"
fi

source "$HOME/.cache/wal/colors.sh"

i3lock \
  --time-font="Hack Nerd Font" \
  --date-font="Hack Nerd Font" \
  --verif-font="Hack Nerd Font" \
  --wrong-font="Hack Nerd Font" \
  --image="$blur" \
  --blur 5 \
  --clock \
  --indicator \
  --ring-width=8 \
  --radius=130 \
  --ring-color=${color4:1}aa \
  --inside-color=00000088 \
  --line-color=00000000 \
  --separator-color=00000000 \
  --keyhl-color=${color5:1}cc \
  --bshl-color=${color1:1}cc \
  --insidever-color=00000088 \
  --ringver-color=${color2:1}cc \
  --insidewrong-color=00000088 \
  --ringwrong-color=${color1:1}cc \
  --verif-color=${foreground:1}aa \
  --wrong-color=${foreground:1}aa \
  --time-color=${foreground:1}ff \
  --date-color=${foreground:1}cc \
  --layout-color=${foreground:1}aa \
  --greeter-color=${foreground:1}aa \
  --time-str="%H:%M:%S" \
  --date-str="%A, %d %B" \
  --noinput-text="" \
  --wrong-text="" \
  --verif-text="" \

