setxkbmap it

dbus-update-activation-environment --systemd DISPLAY XAUTHORITY

startup_wallpaper="$(
    "$HOME/.config/i3/refresh-theme.sh" --prepare-startup
)" || exit 1

# startup_wallpaper="$(
#     "$HOME/.config/i3/refresh-theme.sh" \
#         --prepare-startup "$HOME/Wallpapers/active/lain.jpg"
# )" || exit 1

"$HOME/.config/i3/display_apply.sh" auto "$startup_wallpaper"

exec i3
