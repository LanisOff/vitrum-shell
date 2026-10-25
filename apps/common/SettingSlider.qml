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
    /// Shown while the key is unset (e.g. the value a preset gives).
    property real fallback: from
    readonly property real value: Number(Settings.get(key, fallback))
    Label { anchors.verticalCenter: parent.verticalCenter; text: row.value.toFixed(row.decimals) + row.unit; numeric: true; role: "dim"; width: Tokens.islandHeight * 2; horizontalAlignment: Text.AlignRight }
    // The shared Slider with no icon (the row's label names it); the wheel
    // scrolls the page, as before.
    Slider {
        width: Tokens.islandHeight * 6
        anchors.verticalCenter: parent.verticalCenter
        icon: ""
        wheel: false
        value: Math.max(0, Math.min(1, (row.value - row.from) / (row.to - row.from)))
        onMoved: f => {
            const v = Math.round((row.from + f * (row.to - row.from)) / row.step) * row.step;
            Settings.set(row.key, Number(v.toFixed(row.decimals + 2)));
        }
    }
}
