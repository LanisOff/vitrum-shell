import QtQuick
import qs.services
import qs.theme
import qs.components
import "root:/lib/settingsui.js" as Ui

// A switch bound to a boolean settings key. Held (`heldBy`, e.g. by a master
// switch), it shows on whatever the key says, and the key keeps its value for
// when it is let go.
SettingRow {
    id: row
    property string key: ""
    label: Ui.label(key)
    GlassSwitch {
        anchors.verticalCenter: parent.verticalCenter
        checked: row.held || Settings.get(row.key, false) === true
        onToggled: Settings.set(row.key, !checked)
    }
}
