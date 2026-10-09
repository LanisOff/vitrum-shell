pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/keyboard.js" as Lib

/*
 * Keyboard layout per app (keyboard.perApp): the layout you switch to in an
 * app is remembered for it, and comes back whenever any of its windows takes
 * focus — Telegram in Russian, the terminal in English. The OSD shows each
 * switch. Kept in ~/.local/share/vitrum/layouts.json.
 */
Singleton {
    id: root
    readonly property bool on: Settings.get("keyboard.perApp", true) && Niri.keyboardLayouts.length > 1
    property var map: ({})
    property string app: Niri.focusedWindow ? Niri.focusedWindow.appId : ""

    onAppChanged: {
        if (!on) return;
        const i = Lib.switchTo(map, app, Niri.keyboardLayouts, Niri.keyboardLayoutIndex);
        if (i >= 0) Niri.action("switch-layout", String(i));
    }
    Connections {
        target: Niri
        function onKeyboardLayoutIndexChanged() {
            if (!root.on || !root.app) return;
            const m = Lib.remember(root.map, root.app, Niri.keyboardLayout);
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
