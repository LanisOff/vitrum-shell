import QtQuick
import qs.theme

// A desktop widget's title row: its icon in its own colour, its name in small
// capitals, and an optional value at the far end. Every widget wears the same
// one, so they read as a set.
Item {
    id: root
    property string icon: ""
    property string title: ""
    property string trailing: ""
    property real hue: 0                       // kept for callers; the icon is the accent
    property color tint: Colors.accent
    width: parent ? parent.width : 200
    implicitHeight: Tokens.textSmall + 8
    height: implicitHeight
    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        Icon { name: root.icon; size: Tokens.textSmall + 5; color: root.tint; filled: true; anchors.verticalCenter: parent.verticalCenter }
        Label {
            text: root.title.toUpperCase()
            size: Tokens.textSmall
            font.weight: Font.DemiBold
            font.letterSpacing: 0.9
            color: Colors.textDim
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    Label {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: Math.min(implicitWidth, root.width * 0.55)
        text: root.trailing
        size: Tokens.textSmall
        color: Colors.textDim
        horizontalAlignment: Text.AlignRight
    }
}
