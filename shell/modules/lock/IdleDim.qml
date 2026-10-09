import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme

/*
 * Idle dimming (Idle.dimmed): the screen sinks slowly towards black, and any
 * key or motion brings it straight back. Takes no input — it only darkens —
 * and is gone entirely when not dimming.
 */
PanelWindow {
    id: dim
    required property var modelData
    screen: modelData

    property real level: Idle.dimmed && !UiState.locked ? 1 : 0
    // Slow into the dark, quick out of it.
    Behavior on level { id: fade; NumberAnimation { duration: fade.targetValue > 0.5 ? 2500 : 220; easing.type: Easing.InOutQuad } }

    visible: level > 0.001
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "vitrum-dim"
    mask: Region {}

    Rectangle { anchors.fill: parent; color: "black"; opacity: 0.6 * dim.level }
}
