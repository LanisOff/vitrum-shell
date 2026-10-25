import QtQuick
import qs.theme

// A desktop widget's title row, the same on every widget so they read as a
// set: a plain line icon in accent2 (or in `tint` when a caller gives a
// meaning colour), the name in sentence case, and an optional value at the
// far end.
Item {
    id: root
    property string icon: ""
    property string title: ""
    property string trailing: ""
    property real hue: 0                       // kept for callers; unused
    property color tint: Colors.accent
    width: parent ? parent.width : 200
    implicitHeight: Math.round(Tokens.textSize * 2)
    height: implicitHeight
    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(Tokens.gap * 0.7)
        Icon {
            visible: root.icon.length > 0
            name: root.icon || "help"
            size: Math.round(root.height * 0.72)
            color: Qt.colorEqual(root.tint, Colors.accent) ? Colors.accent2 : root.tint
            anchors.verticalCenter: parent.verticalCenter
        }
        Label {
            text: root.title
            size: Tokens.textSize
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    Label {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: Math.min(implicitWidth, root.width * 0.5)
        text: root.trailing
        size: Tokens.textSmall
        role: "dim"
        horizontalAlignment: Text.AlignRight
    }
}
