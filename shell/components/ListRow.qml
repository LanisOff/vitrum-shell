import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.theme

// One line of a widget's list: an icon (a theme glyph or an image), the title
// with a dim subtitle under it, and a value at the far end.
Item {
    id: root
    property string icon: ""
    property url image: ""
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property bool dim: false
    property color tint: Colors.accent
    width: parent ? parent.width : 200
    implicitHeight: Math.round(subtitle ? Tokens.textSize * 2.8 : Tokens.textSize * 2.1)
    height: implicitHeight
    readonly property bool hasLead: icon !== "" || image.toString() !== ""
    Item {
        id: lead
        visible: root.hasLead
        width: visible ? Math.round(root.height * 0.72) : 0; height: width
        anchors.verticalCenter: parent.verticalCenter
        Icon { anchors.centerIn: parent; visible: root.image.toString() === ""; name: root.icon; color: root.tint; size: Math.round(parent.width * 0.75) }
        IconImage { anchors.fill: parent; visible: root.image.toString() !== ""; source: root.image }
    }
    Column {
        anchors { left: lead.right; leftMargin: root.hasLead ? Tokens.gap * 0.8 : 0; right: tr.left; rightMargin: Tokens.gap * 0.5; verticalCenter: parent.verticalCenter }
        Label { width: parent.width; text: root.title; role: root.dim ? "dim" : "text"; font.weight: Font.Medium }
        Label { width: parent.width; visible: text.length > 0; text: root.subtitle; role: "dim"; size: Tokens.textSmall }
    }
    Label { id: tr; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.trailing; numeric: true; role: "dim"; size: Tokens.textSmall }
}
