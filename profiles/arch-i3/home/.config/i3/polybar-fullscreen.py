#!/usr/bin/env python3

import asyncio
import fcntl
import os
import subprocess
from pathlib import Path

import i3ipc
from i3ipc.aio import Connection

runtime_dir = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))

lock_file = open(runtime_dir / "polybar-fullscreen.lock", "w")

try:
    fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    raise SystemExit(0)


def polybar_instances():
    instances = []

    for proc in Path("/proc").iterdir():
        if not proc.name.isdigit():
            continue

        try:
            if (proc / "comm").read_text().strip() != "polybar":
                continue

            environ = (proc / "environ").read_bytes().split(b"\0")
        except (FileNotFoundError, PermissionError, ProcessLookupError):
            continue

        monitor = None

        for entry in environ:
            if entry.startswith(b"MONITOR="):
                monitor = entry.split(b"=", 1)[1].decode(errors="replace")
                break

        if monitor:
            instances.append((int(proc.name), monitor))

    return instances


async def fullscreen_outputs(i3):
    outputs = [
        output
        for output in await i3.get_outputs()
        if output.active and output.current_workspace
    ]

    active_outputs = {output.name for output in outputs}
    workspace_outputs = {output.current_workspace: output.name for output in outputs}

    tree = await i3.get_tree()
    fullscreen = tree.find_fullscreen()

    if any(container.fullscreen_mode == 2 for container in fullscreen):
        return active_outputs

    hidden = set()

    for container in fullscreen:
        if container.fullscreen_mode != 1:
            continue

        workspace = container.workspace()

        if workspace and workspace.name in workspace_outputs:
            hidden.add(workspace_outputs[workspace.name])

    return hidden


async def sync_bars(i3, _event=None):
    hidden_outputs = await fullscreen_outputs(i3)

    for pid, monitor in polybar_instances():
        command = "hide" if monitor in hidden_outputs else "show"

        subprocess.run(
            ["polybar-msg", "-p", str(pid), "cmd", command],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


async def main():
    i3 = await Connection(auto_reconnect=True).connect()

    i3.on(i3ipc.Event.WINDOW_FULLSCREEN_MODE, sync_bars)
    i3.on(i3ipc.Event.WINDOW_CLOSE, sync_bars)
    i3.on(i3ipc.Event.WINDOW_MOVE, sync_bars)
    i3.on(i3ipc.Event.WINDOW_NEW, sync_bars)
    i3.on(i3ipc.Event.WORKSPACE_FOCUS, sync_bars)
    i3.on(i3ipc.Event.WORKSPACE_MOVE, sync_bars)
    i3.on(i3ipc.Event.OUTPUT, sync_bars)

    await sync_bars(i3)
    await i3.main()


asyncio.run(main())
