pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../lib/pwnodes.js" as Nodes

/*
 * Who is using the microphone, the camera, or the screen right now — for the
 * bar's privacy dots.
 *
 *   microphone  PipeWire streams recording from a source (not from an
 *               output's monitor, and not the shell's own visualizer)
 *   camera      processes holding /dev/video* open (V4L2: browsers, Discord
 *               and OBS open it directly, not through PipeWire)
 *   screen      screen shares through vitrum-portal, and the shell's own
 *               recording
 */
Singleton {
    id: root

    PwObjectTracker { objects: Pipewire.nodes.values.filter(n => n.isStream) }

    function _appOf(n) {
        const p = n.properties || {};
        return p["application.name"] || p["application.process.binary"] || n.description || n.name || "An app";
    }
    function _isMonitor(n) {
        const p = n.properties || {};
        return p["stream.capture.sink"] === "true" || p["stream.monitor"] === "true";
    }
    function _ours(n) {
        const p = n.properties || {};
        const app = (p["application.process.binary"] || p["application.name"] || "").toLowerCase();
        // Ours: the shell, its spectrum (cava), and the noise filter's own capture.
        return app === "quickshell" || app === "qs" || app === "cava" || (n.name || "").startsWith("capture.vitrum_");
    }
    function _unique(list) { return list.filter((x, i) => list.indexOf(x) === i); }

    readonly property var micNodes: Pipewire.nodes.values.filter(n => Nodes.kind(n) === "capture" && n.audio && !_isMonitor(n) && !_ours(n))
    readonly property var micApps: _unique(micNodes.map(_appOf))

    /// [{ pid, name }]
    property var cameraUsers: []
    readonly property var cameraApps: _unique(cameraUsers.map(u => u.name))

    /// [{ session, app }] from vitrum-portal
    property var shares: []
    readonly property var screenApps: _unique(shares.map(s => s.app || "An app").concat(UiState.recording ? ["Screen recording"] : []))

    readonly property bool mic: micApps.length > 0
    readonly property bool camera: cameraApps.length > 0
    readonly property bool screen: screenApps.length > 0
    readonly property bool any: mic || camera || screen

    /// Every stream recording the microphone is muted (by the panel's button).
    readonly property bool micMuted: micNodes.length > 0 && micNodes.every(n => n.audio && n.audio.muted)
    /// Mute every stream recording the microphone (the apps keep running), or
    /// give it back. WirePlumber remembers it per app, so it has to be undoable.
    function toggleMic() { const m = !micMuted; for (const n of micNodes) if (n.audio) n.audio.muted = m; }
    /// End every screen share (vitrum-portal stops the casts; apps see the stream end).
    function stopSharing() {
        Quickshell.execDetached(["gdbus", "call", "--session", "--dest", "org.freedesktop.impl.portal.desktop.vitrum",
                                 "--object-path", "/org/freedesktop/portal/desktop", "--method", "dev.vitrum.ScreenCast.StopAll"]);
        if (UiState.recording) UiState.stopRecording();
    }

    // The camera: /proc scan of this user's processes, every few seconds.
    Process {
        id: camScan
        // One find over every fd (no process per fd): pids holding a video device.
        command: ["sh", "-c", "ls /dev/video* >/dev/null 2>&1 || exit 0; find /proc/[0-9]*/fd -maxdepth 1 -lname '/dev/video*' 2>/dev/null | cut -d/ -f3 | sort -u | while read -r p; do echo \"$p $(cat /proc/$p/comm 2>/dev/null)\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const users = [];
                for (const line of text.split("\n")) {
                    const m = line.match(/^(\d+) (.+)$/);
                    if (m) users.push({ pid: +m[1], name: m[2] });
                }
                if (JSON.stringify(users) !== JSON.stringify(root.cameraUsers)) root.cameraUsers = users;
            }
        }
    }
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!camScan.running) camScan.running = true }

    // Screen shares: vitrum-portal keeps a list in its runtime directory.
    FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/vitrum-screencast/active.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { const d = JSON.parse(text()); root.shares = Array.isArray(d.sessions) ? d.sessions : []; } catch (e) { root.shares = []; } }
        onLoadFailed: root.shares = []
    }
}
