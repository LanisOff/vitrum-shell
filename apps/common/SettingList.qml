import QtQuick
import qs.services
import qs.theme
import qs.components
import "root:/lib/settingsui.js" as Ui

// A list of strings: chips with ×, and a field to add one.
Column {
    id: list
    property string key: ""
    property string label: Ui.label(key)
    property string hint: ""
    property string placeholder: "Add…"
    readonly property var items: Settings.get(key, []) || []
    width: parent ? parent.width : 400
    padding: Tokens.padding
    spacing: Tokens.gap
    Label { text: list.label }
    Label { visible: list.hint.length > 0; width: list.width - 2 * Tokens.padding; text: list.hint; role: "dim"; size: Tokens.textSmall; wrapMode: Text.WordWrap; elide: Text.ElideNone }
    Flow {
        width: list.width - 2 * Tokens.padding
        spacing: Tokens.gap / 2
        Repeater {
            model: list.items
            delegate: Rectangle {
                required property var modelData
                required property int index
                height: Tokens.islandHeight * 1.05; radius: height / 2
                width: chipRow.implicitWidth + Tokens.padding
                color: Colors.alpha(Colors.accent, 0.18)
                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 4
                    Label { text: String(modelData); anchors.verticalCenter: parent.verticalCenter; size: Tokens.textSmall + 1 }
                    Icon { name: "close"; size: Tokens.iconSize * 0.8; anchors.verticalCenter: parent.verticalCenter
                           MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                                       onClicked: { const l = list.items.slice(); l.splice(index, 1); Settings.set(list.key, l); } } }
                }
            }
        }
        Rectangle {
            height: Tokens.islandHeight * 1.05; radius: height / 2
            width: Tokens.islandHeight * 5
            color: Colors.alpha(Colors.text, 0.06)
            TextInput {
                id: add
                anchors { fill: parent; leftMargin: Tokens.gap; rightMargin: Tokens.gap }
                verticalAlignment: TextInput.AlignVCenter
                font.family: Tokens.fontText; font.pixelSize: Tokens.textSmall + 1
                color: Colors.text; clip: true
                onAccepted: { const v = text.trim(); if (v && list.items.indexOf(v) < 0) Settings.set(list.key, list.items.concat([v])); text = ""; }
                Label { visible: !add.text && !add.activeFocus; text: list.placeholder; role: "dim"; size: Tokens.textSmall + 1; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
}
