import QtQuick
import qs.services
import qs.theme
import qs.components
import ".."

// Workspaces of this screen: the active one an accent capsule, others dots with a window count.
BarModule {
    id: root
    shown: Niri.available
    hoverable: false
    readonly property var list: screen ? Niri.workspacesOn(screen.name) : []
    implicitWidth: dots.implicitWidth

    Row {
        id: dots
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.gap / 2
        Repeater {
            model: root.list
            delegate: Rectangle {
                required property var modelData
                readonly property int count: Niri.windowsOn(modelData.id).length
                height: Tokens.iconSize * 0.75
                width: modelData.active ? height * 2.4 : height
                radius: height / 2
                anchors.verticalCenter: parent.verticalCenter
                color: modelData.active ? Colors.accent : count > 0 ? Colors.alpha(Colors.text, 0.55) : Colors.alpha(Colors.text, 0.22)
                Behavior on width { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
                Behavior on color { enabled: Motion.enabled; ColorAnim {} }
                Label {
                    anchors.centerIn: parent
                    visible: parent.modelData.active
                    text: parent.modelData.idx
                    numeric: true; size: Tokens.textSmall; role: "onAccent"; font.weight: Font.DemiBold
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Niri.focusWorkspace(parent.modelData.idx) }
            }
        }
    }
    onWheel: w => Niri.action(w.angleDelta.y > 0 ? "focus-workspace-up" : "focus-workspace-down")
}
