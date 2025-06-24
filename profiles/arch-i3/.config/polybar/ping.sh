ping -c 1 -W 1 1.1.1.1 | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1 " ms"}' || echo "no conn"

