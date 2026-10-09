import QtQuick
import qs.services
import qs.theme
import qs.components

// A number in [from, to], snapped to `step`, shown with its unit.
SettingRow {
    id: row
    property string key: ""
    property real from: 0
    property real to: 1
    property real step: 0.01
    property string unit: ""
    property int decimals: step >= 1 ? 0 : step >= 0.1 ? 1 : 2
    label: key.split(".").pop().replace(/([a-z0-9])([A-Z])/g, "$1 $2").replace(/^./, c => c.toUpperCase())
    readonly property real value: Number(Settings.get(key, from))
    Label { anchors.verticalCenter: parent.verticalCenter; text: row.value.toFixed(row.decimals) + row.unit; numeric: true; role: "dim"; width: Tokens.islandHeight * 2; horizontalAlignment: Text.AlignRight }
    Item {
        width: Tokens.islandHeight * 6; height: Tokens.islandHeight
        anchors.verticalCenter: parent.verticalCenter
        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 6; radius: 3
            color: Colors.alpha(Colors.text, 0.12)
            Rectangle { width: parent.width * Math.max(0, Math.min(1, (row.value - row.from) / (row.to - row.from))); height: parent.height; radius: 3; color: Colors.accent }
        }
        Rectangle {
            width: 16; height: 16; radius: 8
            color: "white"; border.width: 1; border.color: Colors.alpha("#000000", 0.2)
            anchors.verticalCenter: parent.verticalCenter
            x: track.width * Math.max(0, Math.min(1, (row.value - row.from) / (row.to - row.from))) - 8
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function put(px) {
                const f = Math.max(0, Math.min(1, px / width));
                const v = Math.round((row.from + f * (row.to - row.from)) / row.step) * row.step;
                Settings.set(row.key, Number(v.toFixed(row.decimals + 2)));
            }
            onPressed: m => put(m.x)
            onPositionChanged: m => { if (pressed) put(m.x); }
        }
    }
}
