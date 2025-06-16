#!/bin/bash

scrot /tmp/screen_locked.png
convert /tmp/screen_locked.png -blur 0x8 /tmp/screen_locked_blur.png

source "$HOME/.cache/wal/colors.sh"

i3lock \
  --image=/tmp/screen_locked_blur.png \
  --inside-color=${color0:1}ff \
  --ring-color=${color4:1}cc \
  --line-color=00000000 \
  --separator-color=00000000 \
  --insidever-color=${color2:1}ff \
  --ringver-color=${color2:1}cc \
  --insidewrong-color=${color1:1}ff \
  --ringwrong-color=${color1:1}cc \
  --keyhl-color=${color5:1}ff \
  --bshl-color=${color3:1}ff \
  --clock \
  --time-color=${foreground:1}ff \
  --date-color=${foreground:1}ff \
  --time-str="%H:%M:%S" \
  --date-str="%A, %d %B"

