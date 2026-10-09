import QtQuick
import qs.theme

// A Control Centre toggle: icon, title, subtitle; accent when on; a chevron when it has a submenu.
Surface {
    id: root
    property string icon: "help"
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool hasMenu: false
    signal toggled()
    signal expand()

    group: "panels"
    level: 1
    outlined: false
    radius: height / 2
    implicitHeight: Tokens.islandHeight * 1.6
    color: active ? Colors.accent : mouse.containsMouse ? Colors.alpha(Colors.text, 0.12) : Materials.fill(group, 1)

    Row {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding
        anchors.rightMargin: Tokens.padding
        spacing: Tokens.gap
        Icon { name: root.icon; filled: root.active; color: root.active ? Colors.onAccent : Colors.text; anchors.verticalCenter: parent.verticalCenter }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Tokens.iconSize * 2 - Tokens.gap * 2
            Label { width: parent.width; text: root.title; role: root.active ? "onAccent" : "text"; font.weight: Font.DemiBold }
            Label { width: parent.width; visible: text.length > 0; text: root.subtitle; size: Tokens.textSmall; role: root.active ? "onAccent" : "dim" }
        }
        Icon { visible: root.hasMenu; name: "chevron"; color: root.active ? Colors.onAccent : Colors.textDim; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: m => (root.hasMenu && m.x > width - Tokens.iconSize * 2) ? root.expand() : root.toggled()
    }
}
