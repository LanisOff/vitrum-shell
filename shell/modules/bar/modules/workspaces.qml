import QtQuick
import qs.services
import qs.theme
import qs.components
import ".."

// Workspaces of this screen: small glass marks, a brighter one where windows
// are; the active one is wider and tinted.
BarModule {
    id: root
    shown: Niri.available
    hoverable: false
    readonly property var list: screen ? Niri.workspacesOn(screen.name) : []
    // A third of an island (10 at compact density); the active one 2.2 times as wide.
    readonly property int mark: Math.round(Tokens.islandHeight / 3)
    implicitWidth: dots.implicitWidth

    Row {
        id: dots
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.gap / 2
        Repeater {
            model: root.list
            delegate: Rectangle {
                id: ws
                required property var modelData
                readonly property int count: Niri.windowsOn(modelData.id).length
                height: root.mark
                width: modelData.active ? Math.round(root.mark * 2.2) : root.mark
                radius: Tokens.radiusMark
                anchors.verticalCenter: parent.verticalCenter
                // Off: clear glass with a rim; the tint takes the active one over.
                color: modelData.active ? "transparent" : Colors.alpha(Colors.text, count > 0 ? 0.32 : 0.10)
                border.width: Tokens.hairline
                border.color: modelData.active ? "transparent" : Colors.alpha(Colors.text, count > 0 ? 0.40 : 0.22)
                Behavior on width { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }
                Behavior on color { enabled: Motion.enabled; ColorAnim {} }
                Behavior on border.color { enabled: Motion.enabled; ColorAnim {} }
                ShellTint { anchors.fill: parent; radius: ws.radius; group: "bar"; active: ws.modelData.active }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Niri.focusWorkspace(ws.modelData.idx) }
            }
        }
    }
    onWheel: w => Niri.action(w.angleDelta.y > 0 ? "focus-workspace-up" : "focus-workspace-down")
}
