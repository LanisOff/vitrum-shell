import QtQuick
import qs.services
import qs.theme
import qs.components
import ".."

// The column strip of this screen's active workspace: where it is placed, or
// right after the workspaces with their option bar.minimap (lib/bar.js withMinimap).
BarModule {
    id: root
    readonly property var ws: screen ? Niri.activeWorkspaceOn(screen.name) : null
    readonly property var map: ws ? Niri.columns(ws.id, 8) : ({ columns: [], moreLeft: 0, moreRight: 0 })
    shown: Niri.available && map.columns.length > 0
    hoverable: false
    implicitWidth: strip.implicitWidth

    Row {
        id: strip
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(Tokens.gap * 0.4)
        Label { visible: root.map.moreLeft > 0; text: "+" + root.map.moreLeft; size: Tokens.textSmall; role: "dim"; numeric: true }
        Repeater {
            model: root.map.columns
            delegate: Rectangle {
                id: col
                required property var modelData
                height: Tokens.iconSize * 0.7
                width: Math.max(height * 0.8, height * 0.9 * Math.min(2.5, modelData.widthFrac))
                radius: Tokens.radiusMark
                anchors.verticalCenter: parent.verticalCenter
                // The focused column is tinted glass; the others plain marks.
                color: modelData.focused ? "transparent" : Colors.alpha(Colors.text, modelData.visible ? 0.45 : 0.18)
                Behavior on width { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
                Behavior on color { enabled: Motion.enabled; ColorAnim {} }
                ShellTint { anchors.fill: parent; radius: col.radius; group: "bar"; active: col.modelData.focused }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Niri.focusColumn(col.modelData.col) }
            }
        }
        Label { visible: root.map.moreRight > 0; text: "+" + root.map.moreRight; size: Tokens.textSmall; role: "dim"; numeric: true }
    }
    onWheel: w => Niri.action(w.angleDelta.y > 0 ? "focus-column-left" : "focus-column-right")
}
