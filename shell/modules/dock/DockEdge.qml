import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme

/*
 * The strip at the bottom edge that brings a hidden dock back. Its own
 * surface, with a namespace no effect rule matches, so nothing is ever drawn
 * or blurred here — it only notices the pointer.
 */
PanelWindow {
    id: edge
    property var dock: null
    screen: dock ? dock.targetScreen : null
    // Fixed to its dock's screen; there only while that dock is the one in use.
    visible: !!dock && dock.active && dock.enabled_ && dock.targetScreen !== null && Settings.get("dock.intellihide", true)
    anchors { bottom: true }
    implicitWidth: dock ? Math.max(Tokens.islandHeight * 4, dock.plateW) : 200
    implicitHeight: 4
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "vitrum-dock-edge"
    WlrLayershell.layer: WlrLayer.Top
    HoverHandler { onHoveredChanged: if (edge.dock) edge.dock.edgeHovered = hovered }
}
