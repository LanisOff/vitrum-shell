pragma Singleton

import QtQuick
import Quickshell

/*
 * Power off later: in a while, or when the emerge (or pacman) running now has finished
 * (then a minute's grace, in case you are there). The bar shows the countdown
 * as an activity; clicking it cancels.
 */
Singleton {
    id: root
    property real at: 0              // ms since epoch; 0 = not planned
    property bool afterEmerge: false
    property real now: Date.now()
    readonly property bool pending: at > 0 || afterEmerge
    readonly property int secondsLeft: at > 0 ? Math.max(0, Math.round((at - now) / 1000)) : -1
    property bool warned: false

    function inMinutes(m) {
        afterEmerge = false; warned = false;
        at = Date.now() + m * 60000; now = Date.now();
        Notifs.inject("Power", "Powering off in " + (m >= 60 ? (m / 60) + " h" : m + " min"), "Click the countdown in the bar to cancel.");
    }
    function whenEmergeDone() {
        at = 0; warned = false; afterEmerge = true;
        Notifs.inject("Power", "Powering off when " + Packages.toolName + " is done", "If it fails, the computer stays on.");
    }
    function cancel() {
        if (!pending) return;
        at = 0; afterEmerge = false;
        Notifs.inject("Power", "Power off cancelled", "");
    }

    Connections {
        target: Packages
        function onBuilt() {
            if (!root.afterEmerge) return;
            root.afterEmerge = false;
            if (Packages.state.ok) {
                root.at = Date.now() + 60000; root.warned = true;
                Notifs.inject("Power", "The update is done — powering off in a minute", "Click the countdown in the bar to stay on.");
            } else Notifs.inject("Power", "The update failed — staying on", Packages.state.failed || "");
        }
    }
    Timer {
        interval: 1000; repeat: true; running: root.at > 0
        onTriggered: {
            root.now = Date.now();
            if (!root.warned && root.at - root.now <= 60000) {
                root.warned = true;
                Notifs.inject("Power", "Powering off in a minute", "Click the countdown in the bar to cancel.");
            }
            if (root.now >= root.at) { root.at = 0; Power.shutdown(); }
        }
    }
}
