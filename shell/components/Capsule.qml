import QtQuick
import qs.theme

// A pill button: optional icon and label; hover and press states.
Surface {
    id: root
    property string icon: ""
    property string label: ""
    property bool active: false
    signal clicked()

    group: "panels"
    level: 1
    outlined: false
    radius: height / 2
    implicitHeight: Tokens.islandHeight
    implicitWidth: content.implicitWidth + 2 * Tokens.padding
    color: active ? Colors.accent
         : mouse.pressed ? Colors.alpha(Colors.text, 0.16)
         : mouse.containsMouse ? Colors.alpha(Colors.text, 0.10)
         : Materials.fill(group, 1)
    scale: mouse.pressed ? 0.94 : 1
    Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.bouncy } }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Tokens.gap / 2
        Icon { visible: root.icon.length > 0; name: root.icon || "help"; color: root.active ? Colors.onAccent : Colors.text; anchors.verticalCenter: parent.verticalCenter }
        Label { visible: root.label.length > 0; text: root.label; role: root.active ? "onAccent" : "text"; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
