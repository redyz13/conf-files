#!/usr/bin/env python3

import glob
import os
import time

POLL_INTERVAL = 0.02


def find_backlight():
    for device in sorted(glob.glob("/sys/class/backlight/*")):
        brightness = os.path.join(device, "brightness")
        maximum = os.path.join(device, "max_brightness")

        if os.path.isfile(brightness) and os.path.isfile(maximum):
            return brightness, maximum

    return None


while True:
    paths = find_backlight()

    if paths is None:
        time.sleep(5)
        continue

    brightness_path, max_path = paths

    with open(max_path) as f:
        max_brightness = int(f.read().strip())

    fd = os.open(brightness_path, os.O_RDONLY)

    try:
        last_percentage = None

        while True:
            value = int(os.pread(fd, 32, 0).decode().strip())

            percentage = round(value * 100 / max_brightness)

            if percentage != last_percentage:
                print(percentage, flush=True)
                last_percentage = percentage

            time.sleep(POLL_INTERVAL)

    except (OSError, ValueError):
        pass

    finally:
        os.close(fd)

    time.sleep(1)
