import QtQuick
import qs.theme

// An on/off switch capsule.
Item {
    id: root
    property bool checked: false
    signal toggled()
    implicitWidth: Tokens.islandHeight * 1.7
    implicitHeight: Tokens.islandHeight * 0.9
    Rectangle {
        anchors.fill: parent; radius: height / 2
        color: root.checked ? Colors.accent : Colors.alpha(Colors.text, 0.18)
        Behavior on color { enabled: Motion.enabled; ColorAnim {} }
        Rectangle {
            height: parent.height - 6; radius: height / 2
            // Stretched while held, like a finger pressing on it.
            width: height + (press.pressed ? height * 0.35 : 0)
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Colors.onAccent : Colors.text
            Behavior on x { enabled: Motion.enabled; SpringAnim { token: Motion.bouncy } }
            Behavior on width { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
        }
    }
    MouseArea { id: press; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled() }
}
