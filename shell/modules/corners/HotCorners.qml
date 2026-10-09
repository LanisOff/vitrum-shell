import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme

/*
 * Hot corners of one screen: rest the pointer in a corner for a moment and
 * something happens (corners.*: overview, the desktop, the notification
 * centre, the launcher, Control Centre, or nothing). Never the lock screen.
 *
 * Each corner is a tiny surface on the top layer, so a fullscreen window (a
 * game) covers them and they cannot fire there. The pointer has to leave
 * before the same corner fires again.
 */
Scope {
    id: root
    required property var modelData

    readonly property bool enabled: Settings.get("corners.enabled", true)
    readonly property int delay: Settings.get("corners.delay", 150)

    function act(what) {
        switch (what) {
        case "overview": Niri.toggleOverview(); break;
        case "desktop": Niri.toggleDesktop(); break;
        case "notifications": UiState.toggle("centre"); break;
        case "launcher": UiState.toggle("launcher"); break;
        case "control": UiState.openPanel("control", root.modelData, Qt.rect(root.modelData.width - 140, Tokens.gap, 120, Tokens.islandHeight)); break;
        }
    }

    component Corner: PanelWindow {
        id: c
        property string key: ""
        property bool atTop: true
        property bool atLeft: true
        readonly property string action: Settings.get("corners." + key, "none")
        screen: root.modelData
        visible: root.enabled && action !== "none"
        anchors { top: atTop; bottom: !atTop; left: atLeft; right: !atLeft }
        implicitWidth: 2; implicitHeight: 2
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "vitrum-corner"
        WlrLayershell.layer: WlrLayer.Top
        property bool armed: true
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: {
                if (containsMouse && c.armed) dwell.restart();
                else if (!containsMouse) { dwell.stop(); c.armed = true; }
            }
        }
        Timer { id: dwell; interval: root.delay; onTriggered: { c.armed = false; root.act(c.action); } }
    }

    Corner { key: "topLeft"; atTop: true; atLeft: true }
    Corner { key: "topRight"; atTop: true; atLeft: false }
    Corner { key: "bottomLeft"; atTop: false; atLeft: true }
    Corner { key: "bottomRight"; atTop: false; atLeft: false }
}
