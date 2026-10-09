import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components
import qs.common
import "../lib/bar.js" as BarLib

Page {
    id: page
    title: "Bar"
    subtitle: "Islands of modules on the left, in the middle and on the right."
    Section {
        SettingChoice { key: "bar.position"; names: ({ top: "Top", bottom: "Bottom" }) }
        SettingChoice {
            key: "bar.primary"; label: "Primary screen"; hint: "Where the tray lives. Automatic: the top-left screen of the layout."
            values: [""].concat(Quickshell.screens.map(s => s.name)); names: ({ "": "Automatic" })
        }
        SettingToggle { key: "bar.minimap"; label: "Column minimap next to the workspaces"; divider: false }
    }
    Repeater {
        model: [{ key: "bar.layout.left", name: "Left" }, { key: "bar.layout.center", name: "Middle" },
                { key: "bar.layout.activities", name: "Activities (right of the middle, only while running)" }, { key: "bar.layout.right", name: "Right" }]
        delegate: Section {
            id: sec
            required property var modelData
            readonly property string key: modelData.key
            // As the bar reads them: a bare name is an island of one, anything else is dropped.
            readonly property var islands: (Array.isArray(Settings.get(key, [])) ? Settings.get(key, []) : [])
                .map(i => typeof i === "string" ? [i] : Array.isArray(i) ? i.filter(m => typeof m === "string") : null).filter(i => i)
            title: modelData.name
            function save(l) { Settings.set(sec.key, l); }
            Repeater {
                model: sec.islands
                delegate: IslandRow {
                    required property var modelData
                    required property int index
                    island: modelData
                    onChanged: l => { const all = sec.islands.slice(); if (l.length) all[index] = l; else all.splice(index, 1); sec.save(all); }
                }
            }
            SettingRow {
                label: "New island"; divider: false
                Chip_ { text: "Add"; onClicked: sec.save(sec.islands.concat([["cpu"]])) }
            }
        }
    }

    // One island: its modules as chips (← → to move, × to remove), + to add one.
    component IslandRow: Item {
        id: isl
        property var island: []
        property bool adding: false
        signal changed(var list)
        width: parent ? parent.width : 400
        implicitHeight: col.implicitHeight + Tokens.gap * 2
        Column {
            id: col
            x: Tokens.padding; y: Tokens.gap
            width: parent.width - 2 * Tokens.padding
            spacing: Tokens.gap / 2
            Flow {
                width: parent.width
                spacing: 4
                Repeater {
                    model: isl.island
                    delegate: Rectangle {
                        required property string modelData
                        required property int index
                        height: Tokens.islandHeight * 1.05; radius: height / 2
                        width: mr.implicitWidth + Tokens.gap * 2
                        color: Colors.alpha(Colors.accent, 0.18)
                        Row {
                            id: mr; anchors.centerIn: parent; spacing: 2
                            Icon { name: "chevron"; rotation: 180; size: Tokens.iconSize * 0.7; visible: index > 0; anchors.verticalCenter: parent.verticalCenter
                                   MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const l = isl.island.slice(); l.splice(index - 1, 0, l.splice(index, 1)[0]); isl.changed(l); } } }
                            Label { text: modelData; size: Tokens.textSmall + 1; anchors.verticalCenter: parent.verticalCenter }
                            Icon { name: "chevron"; size: Tokens.iconSize * 0.7; visible: index < isl.island.length - 1; anchors.verticalCenter: parent.verticalCenter
                                   MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const l = isl.island.slice(); l.splice(index + 1, 0, l.splice(index, 1)[0]); isl.changed(l); } } }
                            Icon { name: "close"; size: Tokens.iconSize * 0.7; anchors.verticalCenter: parent.verticalCenter
                                   MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const l = isl.island.slice(); l.splice(index, 1); isl.changed(l); } } }
                        }
                    }
                }
                Rectangle {
                    height: Tokens.islandHeight * 1.05; width: height; radius: height / 2
                    color: isl.adding ? Colors.accent : Colors.alpha(Colors.text, 0.08)
                    Icon { anchors.centerIn: parent; name: "add"; size: Tokens.iconSize * 0.8; color: isl.adding ? Colors.onAccent : Colors.text }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: isl.adding = !isl.adding }
                }
            }
            Flow {
                visible: isl.adding
                width: parent.width
                spacing: 4
                Repeater {
                    model: BarLib.modules().filter(m => isl.island.indexOf(m) < 0)
                    delegate: Rectangle {
                        required property string modelData
                        height: Tokens.islandHeight; radius: height / 2; width: al.implicitWidth + Tokens.padding
                        color: am.containsMouse ? Colors.alpha(Colors.accent, 0.3) : Colors.alpha(Colors.text, 0.06)
                        Label { id: al; anchors.centerIn: parent; text: modelData; size: Tokens.textSmall }
                        MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { isl.changed(isl.island.concat([modelData])); isl.adding = false; } }
                    }
                }
            }
        }
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: Tokens.padding } height: 1; color: Colors.alpha(Colors.text, 0.06) }
    }
    component Chip_: Rectangle {
        id: c
        property string text: ""
        signal clicked()
        height: Tokens.islandHeight * 1.05; radius: height / 2; width: cl.implicitWidth + Tokens.padding * 1.6
        color: cm.containsMouse ? Colors.alpha(Colors.text, 0.12) : Colors.alpha(Colors.text, 0.06)
        Label { id: cl; anchors.centerIn: parent; text: c.text }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: c.clicked() }
    }
}
