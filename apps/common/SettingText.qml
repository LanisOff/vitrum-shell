import QtQuick
import qs.services
import qs.theme
import qs.components
import "root:/lib/settingsui.js" as Ui

// A text (or number) value, saved on Enter or when the field loses focus.
SettingRow {
    id: row
    property string key: ""
    property bool numeric: false
    property string placeholder: ""
    property real fieldWidth: Tokens.islandHeight * 8
    label: Ui.label(key)
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: row.fieldWidth; height: Tokens.islandHeight * 1.1; radius: Tokens.radiusInner
        color: Colors.alpha(Colors.text, 0.06)
        border.width: field.activeFocus ? 2 : 0; border.color: Colors.accent
        TextInput {
            id: field
            anchors { fill: parent; leftMargin: Tokens.gap; rightMargin: Tokens.gap }
            verticalAlignment: TextInput.AlignVCenter
            font.family: Tokens.fontText; font.pixelSize: Tokens.textSize
            color: Colors.text; selectionColor: Colors.accent
            clip: true
            text: String(Settings.get(row.key, ""))
            function save() {
                const v = row.numeric ? Number(text) : text;
                if (row.numeric && !isFinite(v)) { text = String(Settings.get(row.key, "")); return; }
                if (v !== Settings.get(row.key, "")) Settings.set(row.key, v);
            }
            onAccepted: save()
            onActiveFocusChanged: if (!activeFocus) save()
            Label { visible: !field.text && !field.activeFocus; text: row.placeholder; role: "dim"; anchors.verticalCenter: parent.verticalCenter }
        }
    }
}
