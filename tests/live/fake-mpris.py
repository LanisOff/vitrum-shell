#!/usr/bin/env python3
"""A pretend MPRIS player for the nested tests: playing, with a title, an
artist, a cover and a moving position.

    fake-mpris.py <title> <artist> <length-seconds> [cover-path]
"""
import sys
import time

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

ROOT, PLAYER, PROPS = "org.mpris.MediaPlayer2", "org.mpris.MediaPlayer2.Player", "org.freedesktop.DBus.Properties"


class Player(dbus.service.Object):
    def __init__(self, bus, title, artist, length, cover):
        super().__init__(bus, "/org/mpris/MediaPlayer2")
        self.start = time.monotonic()
        self.playing = True
        self.titles = [title, "A much longer title for the next track, to change the width", "Short"]
        self.track = 0
        self.meta = dbus.Dictionary({
            "mpris:trackid": dbus.ObjectPath("/vitrum/track/1"),
            "mpris:length": dbus.Int64(int(length * 1e6)),
            "xesam:title": title, "xesam:artist": dbus.Array([artist], signature="s"),
            "xesam:album": "Test", "mpris:artUrl": ("file://" + cover) if cover else "",
        }, signature="sv")

    def _props(self, iface):
        if iface == ROOT:
            return {"Identity": "Fake player", "CanQuit": False, "CanRaise": False, "HasTrackList": False,
                    "SupportedUriSchemes": dbus.Array([], signature="s"), "SupportedMimeTypes": dbus.Array([], signature="s")}
        return {"PlaybackStatus": "Playing" if self.playing else "Paused", "Metadata": self.meta, "Volume": 1.0,
                "Position": dbus.Int64(int((time.monotonic() - self.start) * 1e6)),
                "Rate": 1.0, "MinimumRate": 1.0, "MaximumRate": 1.0, "LoopStatus": "None", "Shuffle": False,
                "CanGoNext": True, "CanGoPrevious": True, "CanPlay": True, "CanPause": True, "CanSeek": True, "CanControl": True}

    @dbus.service.method(PROPS, in_signature="ss", out_signature="v")
    def Get(self, iface, prop):
        return self._props(iface)[prop]

    @dbus.service.method(PROPS, in_signature="s", out_signature="a{sv}")
    def GetAll(self, iface):
        return self._props(iface)

    @dbus.service.method(PROPS, in_signature="ssv")
    def Set(self, iface, prop, value):
        pass

    @dbus.service.signal(PROPS, signature="sa{sv}as")
    def PropertiesChanged(self, iface, changed, invalidated):
        pass

    @dbus.service.method(PLAYER)
    def PlayPause(self):
        self.playing = not self.playing
        self.PropertiesChanged(PLAYER, {"PlaybackStatus": "Playing" if self.playing else "Paused"}, [])

    @dbus.service.method(PLAYER)
    def Next(self):
        self.track = (self.track + 1) % len(self.titles)
        self.meta["xesam:title"] = self.titles[self.track]
        self.meta["mpris:trackid"] = dbus.ObjectPath("/vitrum/track/%d" % (self.track + 1))
        self.PropertiesChanged(PLAYER, {"Metadata": self.meta}, [])

    @dbus.service.method(PLAYER)
    def Previous(self):
        pass

    @dbus.service.method(PLAYER, in_signature="x")
    def Seek(self, offset):
        pass

    @dbus.service.signal(PLAYER, signature="x")
    def Seeked(self, pos):
        pass


def main():
    title, artist, length = sys.argv[1], sys.argv[2], float(sys.argv[3])
    cover = sys.argv[4] if len(sys.argv) > 4 else ""
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    name = dbus.service.BusName("org.mpris.MediaPlayer2.vitrumfake", bus)  # noqa: F841
    Player(bus, title, artist, length, cover)
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
