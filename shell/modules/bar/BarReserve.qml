import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme

// Reserves the bar's strip so windows keep clear of it. Empty: the bar itself
// is a full-screen surface that reserves nothing (so its panels can flow out).
PanelWindow {
    required property var modelData
    screen: modelData
    readonly property bool atTop: Settings.get("bar.position", "top") === "top"
    anchors { left: true; right: true; top: atTop; bottom: !atTop }
    implicitHeight: Tokens.islandHeight + 2 * Tokens.gap
    exclusiveZone: implicitHeight
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "vitrum-bar-reserve"
    WlrLayershell.layer: WlrLayer.Top
}
