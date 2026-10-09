#!/usr/bin/env python3
"""Ask org.freedesktop.portal.ScreenCast for a stream, the way Discord or a
browser does, and write what came back to <out> as JSON.

    screencast-client.py <out.json> [types]      types: 1 screens, 2 windows, 3 both
"""
import json
import sys

import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

out = sys.argv[1]
types = int(sys.argv[2]) if len(sys.argv) > 2 else 3

DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
portal = bus.get_object("org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop")
sc = dbus.Interface(portal, "org.freedesktop.portal.ScreenCast")
sender = bus.get_unique_name()[1:].replace(".", "_")
loop = GLib.MainLoop()
result = {"steps": []}
n = [0]


def request(method, *args, options):
    n[0] += 1
    token = "vt%d" % n[0]
    path = "/org/freedesktop/portal/desktop/request/%s/%s" % (sender, token)
    box = {}

    def on_response(code, results):
        box["code"], box["results"] = int(code), results
        loop.quit()
    bus.add_signal_receiver(on_response, "Response", "org.freedesktop.portal.Request", path=path)
    options = dict(options, handle_token=token)
    getattr(sc, method)(*args, options)
    GLib.timeout_add_seconds(90, loop.quit)
    loop.run()
    result["steps"].append({"method": method, "code": box.get("code")})
    return box.get("code"), box.get("results", {})


def done():
    with open(out, "w") as f:
        json.dump(result, f)
    sys.exit(0)


try:
    result["version"] = int(portal.Get("org.freedesktop.portal.ScreenCast", "version", dbus_interface="org.freedesktop.DBus.Properties"))
    code, res = request("CreateSession", options={"session_handle_token": "vts"})
    if code != 0:
        done()
    session = str(res["session_handle"])
    code, _ = request("SelectSources", dbus.ObjectPath(session), options={"types": dbus.UInt32(types), "multiple": False,
                                                                          "cursor_mode": dbus.UInt32(2)})
    if code != 0:
        done()
    code, res = request("Start", dbus.ObjectPath(session), "", options={})
    result["streams"] = [[int(s[0]), {k: (list(v) if isinstance(v, dbus.Struct) else int(v)) for k, v in s[1].items()}]
                         for s in res.get("streams", [])]
except dbus.DBusException as e:
    result["error"] = str(e)
done()
