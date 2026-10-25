pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Interface sounds, each switched on separately in settings (sounds.*), from
 * a freedesktop sound theme directory. Most are played by whoever does the
 * thing (a notification, a screenshot, the lock); these three are heard here:
 *   volume   once a volume change settles (a key, the bar, a slider);
 *   device   a USB device plugged in or out (udev);
 *   power    the charger plugged in or out (UPower), on a laptop.
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
        // An emptied field in Settings is the default folder, not none.
        const dir = Settings.get("sounds.theme", "") || "/usr/share/sounds/freedesktop/stereo";
        const p = player.createObject(root, { command: ["sh", "-c", "f=\"$1\"; for e in oga ogg wav; do [ -f \"$f.$e\" ] && exec pw-play \"$f.$e\"; done", "_", dir + "/" + files[event]] });
        p.exited.connect(() => p.destroy());
        p.running = true;
    }
    Component { id: player; Process {} }

    // The Settings app shares this code: devices and the charger are the shell's.
    readonly property bool inShell: !Quickshell.env("VITRUM_NO_THEME")

    // ------------------------------------------------------------ volume ---
    // After the change, at the new level: a drag or a held key is one sound.
    Connections {
        target: Audio
        function onFeedback(kind) { if (kind === "volume" && Settings.get("sounds.volume", false)) volumeLater.restart(); }
    }
    Timer { id: volumeLater; interval: 150; onTriggered: root.play("volume") }

    // ----------------------------------------------------------- charger ---
    // Not for the state UPower reports as the shell starts.
    property bool _settled: false
    Timer { running: true; interval: 5000; onTriggered: root._settled = true }
    Connections {
        target: root.inShell ? Power : null
        function onPluggedInChanged() {
            if (root._settled && Power.hasBattery) root.play(Power.pluggedIn ? "powerPlug" : "powerUnplug");
        }
    }

    // ----------------------------------------------------------- devices ---
    // One event per USB device (not per interface); a hub with things on it is
    // a burst, heard once.
    property string _deviceEvent: ""
    Process {
        running: root.inShell && Settings.get("sounds.device", false)
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=usb/usb_device"]
        stdout: SplitParser {
            onRead: line => {
                const m = /^UDEV\s+\[[^\]]*\]\s+(add|remove)\s/.exec(line);
                if (!m) return;
                root._deviceEvent = m[1] === "add" ? "deviceAdded" : "deviceRemoved";
                deviceLater.restart();
            }
        }
    }
    Timer { id: deviceLater; interval: 300; onTriggered: root.play(root._deviceEvent) }
}
