setxkbmap it

xrandr --output eDP-1 --mode 1920x1080 --primary --rate 120.00
xrandr --output HDMI-1 --mode 1920x1080 --rate 60.00 --left-of eDP-1

~/.config/polybar/launch.sh &

exec i3

