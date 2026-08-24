#!/usr/bin/env python3

import select
import subprocess
import sys
import time

from evdev import InputDevice, ecodes, list_devices

DEADZONE_RATIO = 0.08
KEEPALIVE_INTERVAL = 15.0
SCAN_INTERVAL = 2.0

GAMEPAD_BUTTON_MIN = 0x130
GAMEPAD_BUTTON_MAX = 0x13F

CENTERED_AXES = {
    ecodes.ABS_X,
    ecodes.ABS_Y,
    ecodes.ABS_RX,
    ecodes.ABS_RY,
}

TRIGGER_AXES = {
    ecodes.ABS_Z,
    ecodes.ABS_RZ,
    ecodes.ABS_GAS,
    ecodes.ABS_BRAKE,
}

HAT_AXES = {
    ecodes.ABS_HAT0X,
    ecodes.ABS_HAT0Y,
    ecodes.ABS_HAT1X,
    ecodes.ABS_HAT1Y,
    ecodes.ABS_HAT2X,
    ecodes.ABS_HAT2Y,
    ecodes.ABS_HAT3X,
    ecodes.ABS_HAT3Y,
}


def log(message):
    if sys.stdout.isatty():
        print(message, flush=True)


class Controller:
    def __init__(self, path):
        self.dev = InputDevice(path)
        self.pressed_keys = set()
        self.abs_info = {}
        self.abs_state = {}

        for code, info in self.dev.capabilities(absinfo=True).get(ecodes.EV_ABS, []):
            if info is not None:
                self.abs_info[code] = info
                self.abs_state[code] = info.value

    def process(self):
        for event in self.dev.read():
            if event.type == ecodes.EV_KEY:
                if event.value == 1:
                    self.pressed_keys.add(event.code)
                elif event.value == 0:
                    self.pressed_keys.discard(event.code)

            elif event.type == ecodes.EV_ABS:
                if event.code in self.abs_state:
                    self.abs_state[event.code] = event.value

    def active(self):
        if self.pressed_keys:
            return True

        for code, value in self.abs_state.items():
            info = self.abs_info[code]
            span = info.max - info.min

            if span <= 0:
                continue

            if code in HAT_AXES:
                if value != 0:
                    return True

            elif code in CENTERED_AXES:
                center = (info.min + info.max) / 2
                if abs(value - center) > span * DEADZONE_RATIO:
                    return True

            elif code in TRIGGER_AXES:
                threshold = info.min + span * DEADZONE_RATIO
                if value > threshold:
                    return True

        return False

    def close(self):
        self.dev.close()


def is_controller(dev):
    keys = dev.capabilities().get(ecodes.EV_KEY, [])

    return any(GAMEPAD_BUTTON_MIN <= code <= GAMEPAD_BUTTON_MAX for code in keys)


def reset_idle():
    try:
        subprocess.run(
            ["/usr/bin/xset", "s", "reset"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
            timeout=2,
        )
    except (OSError, subprocess.TimeoutExpired):
        pass


def main():
    controllers = {}
    last_scan = 0.0
    last_keepalive = time.monotonic()
    was_active = False

    log("controller-wake started")

    try:
        while True:
            now = time.monotonic()

            if now - last_scan >= SCAN_INTERVAL:
                current_paths = set(list_devices())

                for path in list(controllers):
                    if path not in current_paths:
                        log(f"REMOVED {controllers[path].dev.name}")
                        controllers[path].close()
                        del controllers[path]

                for path in current_paths:
                    if path in controllers:
                        continue

                    try:
                        dev = InputDevice(path)

                        if not is_controller(dev):
                            dev.close()
                            continue

                        dev.close()
                        controller = Controller(path)
                        controllers[path] = controller
                        log(f"ADDED {controller.dev.name}")
                    except (OSError, PermissionError):
                        pass

                last_scan = now

            if controllers:
                try:
                    readable, _, _ = select.select(
                        [controller.dev.fd for controller in controllers.values()],
                        [],
                        [],
                        0.25,
                    )
                except (OSError, ValueError):
                    readable = []
            else:
                time.sleep(0.25)
                readable = []

            for path, controller in list(controllers.items()):
                if controller.dev.fd not in readable:
                    continue

                try:
                    controller.process()
                except OSError:
                    log(f"REMOVED {controller.dev.name}")
                    controller.close()
                    del controllers[path]

            active = any(controller.active() for controller in controllers.values())
            now = time.monotonic()

            if active != was_active:
                log("ACTIVE" if active else "INACTIVE")
                was_active = active

                if active:
                    reset_idle()
                    last_keepalive = now

            if active and now - last_keepalive >= KEEPALIVE_INTERVAL:
                reset_idle()
                log("KEEPALIVE")
                last_keepalive = now

    except KeyboardInterrupt:
        pass
    finally:
        for controller in controllers.values():
            controller.close()

        log("controller-wake stopped")


if __name__ == "__main__":
    main()
