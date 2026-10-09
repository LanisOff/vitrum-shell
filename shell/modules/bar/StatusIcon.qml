import QtQuick
import qs.services
import qs.theme
import qs.components

// A status icon with an optional short label; opens the Control Centre.
BarModule {
    id: root
    property string icon: "help"
    property string label: ""
    property color tint: Colors.text
    property bool filled: false
    panel: "control"
    implicitWidth: row.implicitWidth
    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.gap / 3
        Icon { name: root.icon; color: root.tint; filled: root.filled; anchors.verticalCenter: parent.verticalCenter }
        Label { visible: root.label.length > 0; text: root.label; numeric: true; size: Tokens.textSmall; anchors.verticalCenter: parent.verticalCenter }
    }
}
