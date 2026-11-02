pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/keyboard.js" as Lib

/*
 * Keyboard layout per app (keyboard.perApp): the layout you switch to in an
 * app is remembered for it, and comes back whenever any of its windows takes
 * focus — Telegram in Russian, the terminal in English. The OSD shows each
 * switch. Kept in ~/.local/share/vitrum/layouts.json, by the layout's name,
 * which is the same on niri's path and on fcitx5's (Layouts.qml).
 */
Singleton {
    id: root
    readonly property bool on: Settings.get("keyboard.perApp", true) && Layouts.names.length > 1
    property var map: ({})
    property string app: Niri.focusedWindow ? Niri.focusedWindow.appId : ""

    onAppChanged: {
        if (!on) return;
        const i = Lib.switchTo(map, app, Layouts.names, Layouts.index);
        if (i >= 0) Layouts.setIndex(i);
    }
    Connections {
        target: Layouts
        function onIndexChanged() {
            // Held (a password field, the lock, game mode) is not the user's choice.
            if (!root.on || !root.app || Layouts.held) return;
            const m = Lib.remember(root.map, root.app, Layouts.current);
            if (JSON.stringify(m) !== JSON.stringify(root.map)) { root.map = m; store.setText(JSON.stringify(m)); }
        }
    }
    FileView {
        id: store
        path: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/vitrum/layouts.json"
        printErrors: false
        onLoaded: { try { root.map = JSON.parse(text()) || {}; } catch (e) { root.map = {}; } }
    }
}
