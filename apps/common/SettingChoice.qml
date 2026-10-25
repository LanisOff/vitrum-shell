import QtQuick
import qs.services
import qs.theme
import qs.components
import "root:/lib/settingsui.js" as Ui

// One of a few values, as a segmented control: a glass groove of segments,
// the chosen one tinted (one tint that glides over to a new choice). The
// values come from the enums (settings.enums.json) unless given; `names` maps
// a value to its label.
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
        id: seg
        // The groove's rim around the segments; the chosen tint sits inside it.
        readonly property real inset: Math.round(3 * Tokens.islandHeight / 30)
        readonly property real innerRadius: Math.max(0, Tokens.radiusButton - inset)
        width: chips.implicitWidth + 2 * inset
        height: Tokens.islandHeight * 1.05
        anchors.verticalCenter: parent.verticalCenter
        // The chosen segment. `rev` counts the Repeater's items coming and
        // going, so a model rebuilt with as many values never leaves a dead item.
        property int rev: 0
        readonly property var chosen: { seg.rev; const i = row.values.indexOf(row.current); return i >= 0 && i < chipRep.count ? chipRep.itemAt(i) : null; }
        // The tint glides only after a click. At rest (first layout, a font or
        // density change, a resize) it sits exactly on the chosen segment.
        property bool glide: false
        function startGlide() { seg.glide = Motion.enabled; settle.restart(); }
        Timer {
            id: settle
            interval: Motion.emphasized
            onTriggered: { if (glideX.running || glideW.running) restart(); else seg.glide = false; }
        }
        Surface {
            anchors.fill: parent
            group: "panels"; level: 1; outlined: true
            radius: Tokens.radiusButton
        }
        ShellTint {
            readonly property real toX: seg.inset + (seg.chosen ? seg.chosen.x : 0)
            readonly property real toW: seg.chosen ? seg.chosen.width : 0
            property real glidingX: toX
            property real glidingW: toW
            Behavior on glidingX { enabled: seg.glide; SpringAnim { id: glideX; token: Motion.smooth } }
            Behavior on glidingW { enabled: seg.glide; SpringAnim { id: glideW; token: Motion.smooth } }
            x: seg.glide ? glidingX : toX
            y: seg.inset
            width: seg.glide ? glidingW : toW
            height: chips.height
            radius: seg.innerRadius
            active: seg.chosen !== null
            hovered: seg.chosen !== null && seg.chosen.hovered
        }
        Row {
            id: chips
            x: seg.inset; y: seg.inset
            Repeater {
                id: chipRep
                model: row.values
                onItemAdded: seg.rev++
                onItemRemoved: seg.rev++
                delegate: Item {
                    required property var modelData
                    readonly property bool on: modelData === row.current
                    readonly property bool hovered: m.containsMouse
                    height: seg.height - 2 * seg.inset
                    width: t.implicitWidth + Tokens.padding * 1.4
                    scale: m.pressed ? 0.97 : 1
                    Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
                    // The lift under the pointer, on a clear segment.
                    Rectangle {
                        anchors.fill: parent
                        radius: seg.innerRadius
                        color: Colors.alpha(Colors.text, !parent.on && m.containsMouse ? 0.06 : 0)
                        Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
                    }
                    Label { id: t; anchors.centerIn: parent; text: row.names[modelData] || Ui.label(String(modelData)); role: parent.on || m.containsMouse ? "text" : "dim"; size: Tokens.textSmall + 1 }
                    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { seg.startGlide(); row.setter(modelData); } }
                }
            }
        }
    }
}
