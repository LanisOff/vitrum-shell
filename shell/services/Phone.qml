pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Your phone, through KDE Connect (tools/vitrum-phone): the paired devices,
 * which are in reach, their battery. Its notifications arrive on their own
 * (kdeconnectd sends them to the notification server, with a reply field).
 */
Singleton {
    id: root
    property var devices: []          // [{ id, name, type, reachable, charge, charging }]
    readonly property var phone: devices.find(d => d.reachable) || devices[0] || null
    readonly property bool connected: !!phone && phone.reachable
    property bool installed: false

    function ring(d) { Quickshell.execDetached(["vitrum-phone", "ring", (d || phone).id]); }
    function ping(d) { Quickshell.execDetached(["vitrum-phone", "ping", (d || phone).id]); }
    function browse(d) { Quickshell.execDetached(["vitrum-phone", "browse", (d || phone).id]); }
    function share(path, d) { Quickshell.execDetached(["vitrum-phone", "share", (d || phone).id, path]); }
    function settings() { Quickshell.execDetached(["kdeconnect-app"]); }

    Process {
        id: poll
        command: ["sh", "-c", 'command -v kdeconnectd >/dev/null || [ -e /usr/share/dbus-1/services/org.kde.kdeconnect.service ] || { echo NONE; exit 0; }; exec vitrum-phone']
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "NONE") { root.installed = false; root.devices = []; return; }
                root.installed = true;
                try { const d = JSON.parse(text); if (JSON.stringify(d) !== JSON.stringify(root.devices)) root.devices = d; } catch (e) {}
            }
        }
    }
    Timer { interval: root.connected ? 30000 : 60000; repeat: true; running: true; triggeredOnStart: true; onTriggered: if (!poll.running) poll.running = true }
}
