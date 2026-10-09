import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import qs.common
import "../lib/settingsui.js" as Ui
import "../lib/settings.js" as Lib

// The settings file as JSON. Apply writes it only when it parses; wrong
// values inside are warned about and fall back to their defaults.
Page {
    id: page
    title: "Advanced"
    subtitle: "vitrum's own updates, and settings.json as text."

    property var result: null
    function check() { result = Ui.checkRaw(editor.text, raw => Lib.validate(raw, Settings.defaults, Settings.enums)); return result; }

    FileView { id: file; path: Settings.path; watchChanges: true; onLoaded: if (!editor.activeFocus) editor.text = text(); onLoadFailed: editor.text = "{}\n" }

    Section {
        title: "vitrum updates"
        note: "From the repository vitrum was installed from (vitrum update). Nothing is pulled until you press Update."
        SettingToggle { key: "updates.vitrum.check"; label: "Check for new versions"; hint: "Quietly, every few hours. An island appears in the bar when there is enough new." }
        SettingSlider { key: "updates.vitrum.threshold"; label: "Show the island from"; from: 1; to: 30; step: 1; unit: " commits" }
        SettingSlider { key: "updates.vitrum.hours"; label: "Check every"; from: 1; to: 24; step: 1; unit: " h"; divider: false }
    }
    Section {
        title: "settings.json"
        note: "Only what parses is applied; a wrong value falls back to its default."
        Item {
            width: parent.width
            height: Math.max(360, page.height - 260)
            Flickable {
                id: flick
                anchors { fill: parent; margins: Tokens.padding }
                contentHeight: editor.implicitHeight
                clip: true
                TextEdit {
                    id: editor
                    width: flick.width
                    font.family: Tokens.fontMono
                    font.pixelSize: Tokens.textSize
                    color: Colors.text
                    selectionColor: Colors.accent
                    wrapMode: TextEdit.NoWrap
                    onTextChanged: page.result = null
                }
            }
        }
    }
    Row {
        spacing: Tokens.gap
        Button_ { text: "Check"; onClicked: page.check() }
        Button_ { text: "Apply"; accent: true; onClicked: { if (page.check().ok) file.setText(editor.text.trim() ? editor.text : "{}\n"); } }
        Button_ { text: "Revert"; onClicked: { editor.text = file.text(); page.result = null; } }
    }
    Column {
        visible: page.result !== null
        width: parent.width
        spacing: 4
        Label { visible: page.result && page.result.ok && !page.result.warnings.length; text: "Looks good."; role: "accent" }
        Repeater { model: page.result ? page.result.errors : []; delegate: Label { required property string modelData; text: modelData; role: "danger"; width: parent.width; wrapMode: Text.WordWrap; elide: Text.ElideNone } }
        Repeater { model: page.result ? page.result.warnings : []; delegate: Label { required property string modelData; text: "• " + modelData; role: "dim"; width: parent.width; wrapMode: Text.WordWrap; elide: Text.ElideNone } }
    }

    component Button_: Rectangle {
        id: b
        property string text: ""
        property bool accent: false
        signal clicked()
        height: Tokens.islandHeight * 1.2; radius: height / 2
        width: bl.implicitWidth + Tokens.padding * 2
        color: accent ? Colors.accent : bm.containsMouse ? Colors.alpha(Colors.text, 0.12) : Colors.alpha(Colors.text, 0.06)
        Label { id: bl; anchors.centerIn: parent; text: b.text; role: b.accent ? "onAccent" : "text"; font.weight: Font.DemiBold }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    }
}
