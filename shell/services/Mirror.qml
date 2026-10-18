pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/displays.js" as D

/*
 * Screen mirroring, which niri does not do itself: for each "mirror" set in
 * Settings → Displays (displays.json), a wl-mirror of the source screen,
 * fullscreen on the target — the window rule in displays.kdl puts it there.
 * Started again if it dies, while both screens are connected.
 */
Singleton {
    id: root
    readonly property string file: Quickshell.env("HOME") + "/.config/vitrum/niri/displays.json"
    property var edits: ({})
    readonly property var present: Quickshell.screens.map(s => s.name)
    readonly property var pairs: D.mirrors(edits, present)
    readonly property bool active: pairs.length > 0

    FileView {
        path: root.file
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.edits = JSON.parse(text()) || {}; } catch (e) { root.edits = {}; } }
        onLoadFailed: root.edits = {}
    }

    Instantiator {
        model: root.pairs
        delegate: Process {
            id: mirror
            required property var modelData
            running: true
            command: ["wl-mirror", "--title", D.mirrorTitle(modelData.source, modelData.target),
                      "--fullscreen-output", modelData.target, "--show-cursor", modelData.source]
            onExited: code => { if (code !== 0) console.warn("mirror: wl-mirror exited with", code); again.restart(); }
            property Timer again: Timer { interval: 3000; onTriggered: mirror.running = true }
        }
    }
}
