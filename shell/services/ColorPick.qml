pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

/*
 * The colour picker: freezes every screen (grim), the picker overlay shows the
 * frozen picture with a loupe; a click copies the colour (hex, or rgb() with
 * Shift) and adds it to the history (picker.history, newest first, 12 kept).
 */
Singleton {
    id: root
    property bool active: false
    property int stamp: 0
    readonly property string dir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/vitrum-picker"
    function frozen(name) { return "file://" + dir + "/" + name + ".png"; }
    readonly property var history: Settings.get("picker.history", []) || []

    function start() {
        if (active || grab.running) return;
        // Whatever was open closes first and fades out before the screen is frozen.
        const wasOpen = UiState.anyOpen;
        UiState.closeAll();
        grab.command = ["sh", "-c", 'd="$1"; shift; mkdir -p "$d" && for o; do grim -o "$o" "$d/$o.png" || exit 1; done', "_", dir]
            .concat(Quickshell.screens.map(s => s.name));
        if (wasOpen) settle.restart(); else grab.running = true;
    }
    Timer { id: settle; interval: Motion.emphasized + 80; onTriggered: grab.running = true }
    Process {
        id: grab
        onExited: code => {
            if (code !== 0) { Notifs.inject("Colour picker", "Could not capture the screen", "grim failed."); return; }
            root.stamp++;
            root.active = true;
        }
    }
    function cancel() { active = false; }

    function pick(hex, asRgb) {
        active = false;
        const c = Qt.color(hex);
        const text = asRgb ? "rgb(" + Math.round(c.r * 255) + ", " + Math.round(c.g * 255) + ", " + Math.round(c.b * 255) + ")" : hex;
        Quickshell.execDetached(["wl-copy", "--", text]);
        remember(hex);
        Notifs.inject("Colour picker", text + " copied", "");
    }
    function remember(hex) {
        Settings.set("picker.history", [hex].concat(history.filter(h => h !== hex)).slice(0, 12));
    }
    function copy(hex) { Quickshell.execDetached(["wl-copy", "--", hex]); remember(hex); }
}
