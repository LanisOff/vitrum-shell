import QtQuick
import qs.services
import qs.theme
import qs.components
import ".."

// The column strip of this screen's active workspace (settings: bar.minimap).
BarModule {
    id: root
    readonly property var ws: screen ? Niri.activeWorkspaceOn(screen.name) : null
    readonly property var map: ws ? Niri.columns(ws.id, 8) : ({ columns: [], moreLeft: 0, moreRight: 0 })
    shown: Niri.available && Settings.get("bar.minimap", false) && map.columns.length > 0
    hoverable: false
    implicitWidth: strip.implicitWidth

    Row {
        id: strip
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Label { visible: root.map.moreLeft > 0; text: "+" + root.map.moreLeft; size: Tokens.textSmall; role: "dim"; numeric: true }
        Repeater {
            model: root.map.columns
            delegate: Rectangle {
                required property var modelData
                height: Tokens.iconSize * 0.7
                width: Math.max(height * 0.8, height * 0.9 * Math.min(2.5, modelData.widthFrac))
                radius: height / 3
                anchors.verticalCenter: parent.verticalCenter
                color: modelData.focused ? Colors.accent : Colors.alpha(Colors.text, modelData.visible ? 0.45 : 0.18)
                Behavior on width { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Niri.focusColumn(parent.modelData.col) }
            }
        }
        Label { visible: root.map.moreRight > 0; text: "+" + root.map.moreRight; size: Tokens.textSmall; role: "dim"; numeric: true }
    }
    onWheel: w => Niri.action(w.angleDelta.y > 0 ? "focus-column-left" : "focus-column-right")
}
