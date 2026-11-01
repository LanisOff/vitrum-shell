import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

/*
 * What opens the welcome tour on a fresh install, and what makes it seen once:
 * the installer's marker, ~/.local/share/vitrum/welcome. Apart from the tour's
 * window, which exists only while it is wanted (shell.qml).
 */
Scope {
    id: root
    readonly property string path: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/vitrum/welcome"

    // At shell start: its being there opens the tour.
    FileView {
        path: root.path
        printErrors: false
        onLoaded: UiState.welcome = true
    }
    Process { id: forget; command: ["rm", "-f", root.path] }
    // Closed by any means (closeAll, closeOverlays, IPC, finish): seen once.
    Connections {
        target: UiState
        function onWelcomeChanged() { if (!UiState.welcome) forget.running = true; }
    }
}
