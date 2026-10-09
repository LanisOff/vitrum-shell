import QtQuick
import qs.theme
import qs.components

// One row in a section: label (and hint) on the left, the control on the right.
Item {
    id: row
    property string label: ""
    property string hint: ""
    default property alias control: slot.data
    property bool divider: true
    width: parent ? parent.width : 400
    // Tall enough for the control too: chips that wrap to a second line spilled out of the card.
    implicitHeight: Math.max(Tokens.islandHeight * 1.6, texts.implicitHeight + Tokens.gap * 2, slot.implicitHeight + Tokens.gap * 2)
    HoverHandler { id: hover }
    Rectangle {
        anchors { fill: parent; margins: 3 }
        radius: Tokens.radiusInner - 3
        color: Colors.alpha(Colors.text, hover.hovered ? 0.04 : 0)
        Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
    }
    Column {
        id: texts
        anchors { left: parent.left; leftMargin: Tokens.padding; verticalCenter: parent.verticalCenter; right: slot.left; rightMargin: Tokens.gap }
        Label { width: parent.width; text: row.label }
        Label { visible: row.hint.length > 0; width: parent.width; text: row.hint; role: "dim"; size: Tokens.textSmall; wrapMode: Text.WordWrap; elide: Text.ElideNone }
    }
    Row {
        id: slot
        anchors { right: parent.right; rightMargin: Tokens.padding; verticalCenter: parent.verticalCenter }
        spacing: Tokens.gap
    }
    Rectangle { visible: row.divider; anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: Tokens.padding } height: 1; color: Colors.alpha(Colors.text, 0.06) }
}
