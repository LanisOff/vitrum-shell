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
    /// Optional: text → the value to save, or undefined to refuse it (the
    /// field shows the saved value again), e.g. a time that is not one.
    property var normalize: null
    label: Ui.label(key)
    // A glass field, as Field.
    Surface {
        anchors.verticalCenter: parent.verticalCenter
        width: row.fieldWidth; height: Tokens.islandHeight * 1.1; radius: Tokens.radiusButton
        group: "panels"; level: 1
        border.width: field.activeFocus ? 2 : Tokens.hairline
        border.color: field.activeFocus ? Colors.accent : Materials.border(group)
        TextInput {
            id: field
            anchors { fill: parent; leftMargin: Tokens.gap; rightMargin: Tokens.gap }
            verticalAlignment: TextInput.AlignVCenter
            font.family: Tokens.fontText; font.pixelSize: Tokens.textSize
            color: Colors.text; selectionColor: Colors.accent
            clip: true
            text: String(Settings.get(row.key, ""))
            function save() {
                const v = row.normalize ? row.normalize(text) : row.numeric ? Number(text) : text;
                if (v !== undefined && !(row.numeric && !isFinite(v)) && v !== Settings.get(row.key, "")) Settings.set(row.key, v);
                // Back to the saved value (refused, or tidied by normalize), still bound to it.
                text = Qt.binding(() => String(Settings.get(row.key, "")));
            }
            onAccepted: save()
            onActiveFocusChanged: if (!activeFocus) save()
            Label { visible: !field.text && !field.activeFocus; text: row.placeholder; role: "dim"; anchors.verticalCenter: parent.verticalCenter }
        }
    }
}
