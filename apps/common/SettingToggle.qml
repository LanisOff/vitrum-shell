import QtQuick
import qs.services
import qs.theme
import qs.components
import "root:/lib/settingsui.js" as Ui

// A switch bound to a boolean settings key.
SettingRow {
    id: row
    property string key: ""
    label: Ui.label(key)
    Toggle {
        checked: Settings.get(row.key, false) === true
        onToggled: Settings.set(row.key, !checked)
    }
}
