import QtQuick
import qs.services
import qs.theme
import qs.components
import "root:/lib/settingsui.js" as Ui

// One of a few values, as a row of chips. The values come from the enums
// (settings.enums.json) unless given; `names` maps a value to its label.
SettingRow {
    id: row
    property string key: ""
    property var values: Ui.options(Settings.enums, key)
    property var names: ({})
    label: Ui.label(key)
    readonly property var current: Settings.get(key, "")
    // How a choice is stored; a pane can replace it (e.g. "default" removes an override).
    property var setter: v => Settings.set(row.key, v)
    Item {
        width: chips.implicitWidth
        height: chips.implicitHeight
        // The chosen chip's capsule: one shape that springs over to a new choice.
        readonly property Item chosen: { chipRep.count; const i = row.values.indexOf(row.current); return i >= 0 ? chipRep.itemAt(i) : null; }
        Rectangle {
            visible: parent.chosen !== null
            x: parent.chosen ? parent.chosen.x : 0
            width: parent.chosen ? parent.chosen.width : 0
            height: chips.implicitHeight
            radius: height / 2
            color: Colors.accent
            Behavior on x { enabled: Motion.enabled; SpringAnim { token: Motion.bouncy } }
            Behavior on width { enabled: Motion.enabled; SpringAnim { token: Motion.bouncy } }
        }
        Row {
            id: chips
            spacing: 4
            Repeater {
                id: chipRep
                model: row.values
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: modelData === row.current
                    height: Tokens.islandHeight * 1.05
                    width: t.implicitWidth + Tokens.padding * 1.4
                    radius: height / 2
                    color: on ? "transparent" : m.containsMouse ? Colors.alpha(Colors.text, 0.1) : Colors.alpha(Colors.text, 0.05)
                    Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
                    scale: m.pressed ? 0.92 : 1
                    Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.bouncy } }
                    Label { id: t; anchors.centerIn: parent; text: row.names[modelData] || Ui.label(String(modelData)); role: parent.on ? "onAccent" : "text"; size: Tokens.textSmall + 1 }
                    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: row.setter(modelData) }
                }
            }
        }
    }
}
