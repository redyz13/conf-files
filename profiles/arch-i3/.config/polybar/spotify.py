#!/usr/bin/env python3

import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

SERVICE = "org.mpris.MediaPlayer2.spotify"
PATH = "/org/mpris/MediaPlayer2"
PLAYER = "org.mpris.MediaPlayer2.Player"
PROPERTIES = "org.freedesktop.DBus.Properties"


def print_metadata(metadata):
    try:
        artist = metadata["xesam:artist"][0]
        title = metadata["xesam:title"]
        print(f"{artist} - {title}", flush=True)
    except (KeyError, IndexError, TypeError):
        print("spotify closed", flush=True)


def read_current_metadata():
    try:
        obj = bus.get_object(SERVICE, PATH)
        properties = dbus.Interface(obj, PROPERTIES)
        metadata = properties.Get(PLAYER, "Metadata")
        print_metadata(metadata)
    except dbus.DBusException:
        print("spotify closed", flush=True)


def on_properties_changed(interface, changed, invalidated, sender=None):
    if interface != PLAYER:
        return

    try:
        if sender != bus.get_name_owner(SERVICE):
            return
    except dbus.DBusException:
        return

    if "Metadata" in changed:
        print_metadata(changed["Metadata"])


def on_name_owner_changed(name, old_owner, new_owner):
    if name != SERVICE:
        return

    if new_owner:
        read_current_metadata()
    else:
        print("spotify closed", flush=True)


DBusGMainLoop(set_as_default=True)

bus = dbus.SessionBus()

bus.add_signal_receiver(
    on_properties_changed,
    signal_name="PropertiesChanged",
    dbus_interface=PROPERTIES,
    path=PATH,
    sender_keyword="sender",
)

bus.add_signal_receiver(
    on_name_owner_changed,
    signal_name="NameOwnerChanged",
    dbus_interface="org.freedesktop.DBus",
    arg0=SERVICE,
)

read_current_metadata()

try:
    GLib.MainLoop().run()
except KeyboardInterrupt:
    pass
