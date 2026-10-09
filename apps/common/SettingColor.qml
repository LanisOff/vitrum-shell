import QtQuick
import qs.services
import qs.theme
import qs.components
import "root:/lib/settingsui.js" as Ui

// A colour as #rrggbb (or empty for "none"), with a few swatches.
SettingRow {
    id: row
    property string key: ""
    property var swatches: ["", "#5b8def", "#7c6cf0", "#d4628d", "#e5734b", "#d9a43b", "#4fa66b", "#3aa6a6"]
    label: Ui.label(key)
    readonly property string current: Settings.get(key, "")
    Repeater {
        model: row.swatches
        delegate: Rectangle {
            required property string modelData
            anchors.verticalCenter: parent.verticalCenter
            width: Tokens.islandHeight * 0.9; height: width; radius: width / 2
            color: modelData || "transparent"
            border.width: modelData === row.current ? 3 : 1
            border.color: modelData === row.current ? Colors.text : Colors.alpha(Colors.text, 0.2)
            Icon { visible: !modelData; anchors.centerIn: parent; name: "close"; size: Tokens.iconSize * 0.7; color: Colors.textDim }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Settings.set(row.key, modelData) }
        }
    }
}
