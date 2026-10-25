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
    function check() { result = Ui.checkRaw(editor.text, raw => Lib.validate(raw, Settings.defaults, Settings.enums)); reveal.restart(); return result; }
    // The verdict is under the buttons, past the bottom of the page: scroll
    // down to it once it is laid out.
    Timer { id: reveal; interval: 60; onTriggered: page.contentY = Math.max(0, page.contentHeight - page.height) }

    // Follows the file (the switches above write it too), unless you have
    // edited the text: Apply would otherwise put back what the file was.
    property string loaded: ""
    // FileView sends no fileChanged for its own write: what Apply wrote is
    // what Revert goes back to (it went back to the text from before Apply).
    function apply() {
        if (!check().ok) return;
        const t = editor.text.trim() ? editor.text : "{}\n";
        file.setText(t);
        if (editor.text !== t) editor.text = t;
        loaded = t;
    }
    FileView {
        id: file
        path: Settings.path
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { const t = text(); if (editor.text === page.loaded) editor.text = t; page.loaded = t; }
        onLoadFailed: if (editor.text === page.loaded) { editor.text = "{}\n"; page.loaded = editor.text; }
    }

    Section {
        title: "vitrum updates"
        note: "From the repository vitrum was installed from (vitrum update). Nothing is pulled until you press Update."
        SettingToggle { key: "updates.vitrum.check"; label: "Check for new versions"; hint: "Quietly, every few hours. An island appears in the bar when there is enough new." }
        // No unit: " commits" did not fit beside the slider ("16 com…") and read "1 commits".
        SettingSlider { key: "updates.vitrum.threshold"; needs: "updates.vitrum.check"; label: "New commits to show the island"; from: 1; to: 30; step: 1 }
        SettingSlider { key: "updates.vitrum.hours"; needs: "updates.vitrum.check"; label: "Check every"; from: 1; to: 24; step: 1; unit: " h"; divider: false }
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
                contentHeight: editor.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                // The caret stays in view while typing or moving with the keys.
                function follow(r) {
                    if (contentY > r.y) contentY = r.y;
                    else if (contentY + height < r.y + r.height) contentY = r.y + r.height - height;
                }
                TextEdit {
                    id: editor
                    width: flick.width
                    // The whole box takes a click: a short file left most of
                    // it under no text, and a click there never focused it.
                    height: Math.max(implicitHeight, flick.height)
                    font.family: Tokens.fontMono
                    font.pixelSize: Tokens.textSize
                    color: Colors.text
                    selectionColor: Colors.accent
                    selectByMouse: true
                    // A file on one line (as other tools write it) was cut off
                    // at the box's edge, with no way to see the rest.
                    wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                    onTextChanged: page.result = null
                    onCursorRectangleChanged: if (activeFocus) flick.follow(cursorRectangle)
                }
            }
        }
    }
    Row {
        spacing: Tokens.gap
        GlassButton { label: "Check"; height: Tokens.islandHeight * 1.2; onClicked: page.check() }
        GlassButton { label: "Apply"; primary: true; height: Tokens.islandHeight * 1.2; onClicked: page.apply() }
        GlassButton { label: "Revert"; height: Tokens.islandHeight * 1.2; onClicked: { editor.text = page.loaded; page.result = null; } }
    }
    Column {
        visible: page.result !== null
        width: parent.width
        spacing: 4
        Label { visible: page.result && page.result.ok && !page.result.warnings.length; text: "Looks good."; role: "accent" }
        Repeater { model: page.result ? page.result.errors : []; delegate: Label { required property string modelData; text: modelData; role: "danger"; width: parent.width; wrapMode: Text.WordWrap; elide: Text.ElideNone } }
        Repeater { model: page.result ? page.result.warnings : []; delegate: Label { required property string modelData; text: "• " + modelData; role: "dim"; width: parent.width; wrapMode: Text.WordWrap; elide: Text.ElideNone } }
    }
}
