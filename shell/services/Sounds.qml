pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Interface sounds, each switched on separately in settings (sounds.*), from
 * a freedesktop sound theme directory.
 */
Singleton {
    id: root
    readonly property var files: ({
        notification: "message-new-instant",
        screenshot: "camera-shutter",
        volume: "audio-volume-change",
        lock: "service-logout",
        unlock: "service-login",
        deviceAdded: "device-added",
        deviceRemoved: "device-removed",
        powerPlug: "power-plug",
        powerUnplug: "power-unplug"
    })
    readonly property var setting: ({ notification: "notification", screenshot: "screenshot", volume: "volume",
                                      lock: "lock", unlock: "lock", deviceAdded: "device", deviceRemoved: "device",
                                      powerPlug: "power", powerUnplug: "power" })

    function play(event) {
        if (!Settings.get("sounds." + (setting[event] || event), false)) return;
        const dir = Settings.get("sounds.theme", "/usr/share/sounds/freedesktop/stereo");
        const p = player.createObject(root, { command: ["sh", "-c", "f=\"$1\"; for e in oga ogg wav; do [ -f \"$f.$e\" ] && exec pw-play \"$f.$e\"; done", "_", dir + "/" + files[event]] });
        p.exited.connect(() => p.destroy());
        p.running = true;
    }
    Component { id: player; Process {} }
}
