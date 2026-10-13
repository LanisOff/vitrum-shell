import QtQuick
import qs.theme

// A desktop widget's title row, the same on every widget so they read as a
// set: the icon in a tonal circle (Material 3's icon container), the name in
// sentence case, and an optional value at the far end.
Item {
    id: root
    property string icon: ""
    property string title: ""
    property string trailing: ""
    property real hue: 0                       // kept for callers; the tint is what counts
    property color tint: Colors.accent
    width: parent ? parent.width : 200
    implicitHeight: Math.round(Tokens.textSize * 2)
    height: implicitHeight
    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(Tokens.gap * 0.7)
        Rectangle {
            width: root.height; height: width; radius: width / 2
            color: Colors.alpha(root.tint, Colors.dark ? 0.22 : 0.16)
            anchors.verticalCenter: parent.verticalCenter
            Icon { anchors.centerIn: parent; name: root.icon; size: Math.round(parent.width * 0.58); color: root.tint; filled: true }
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
