import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components
import "widgets"

/*
 * The editor's Custom tab: your script widgets (a command and a template,
 * made right here, with a live preview that runs the command) and your QML
 * widgets (folders in ~/.config/vitrum/widgets, found by CustomWidgets).
 */
Item {
    id: tab
    property string screenName: ""
    property int barSpace: 0
    /// The script being edited (a copy), or null for the lists.
    property var editing: null
    readonly property var icons: ["code", "terminal", "cpu", "memory", "disk", "network-off", "wifi", "speed", "temperature", "battery", "music", "weather-partly", "calendar", "clock", "timer", "notifications", "graph", "world", "gamepad", "folder"]
    readonly property var templates: [{ v: "value", l: "Value" }, { v: "progress", l: "Progress" }, { v: "list", l: "List" }, { v: "graph", l: "Graph" }, { v: "text", l: "Text" }]

    function newScript() {
        editing = { id: "s" + Date.now().toString(36), name: "My widget", icon: "code", interval: 10, template: "value",
                    command: "echo \"$(uptime -p | sed 's/up //')\"; echo Uptime" };
    }
    function put(k, v) { const e = Object.assign({}, editing); e[k] = v; editing = e; }

    // ------------------------------------------------------------ lists ---
    Flickable {
        anchors.fill: parent
        visible: !tab.editing
        contentHeight: lists.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: lists
            width: parent.width
            spacing: Tokens.gap
            Row {
                spacing: Tokens.gap
                Label { text: "Script widgets"; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
            }
            Label { width: parent.width; wrapMode: Text.WordWrap; elide: Text.ElideNone; role: "dim"; size: Tokens.textSmall + 1
                    text: "A shell command run every few seconds; what it prints is the widget. Plain lines (value, subtitle, items) or JSON." }
            Repeater {
                model: CustomWidgets.scripts
                delegate: Rectangle {
                    required property var modelData
                    width: lists.width; height: Tokens.islandHeight * 2.1; radius: Tokens.radiusTile
                    color: Colors.alpha(Colors.text, Colors.dark ? 0.055 : 0.04)
                    Row {
                        anchors { left: parent.left; leftMargin: Tokens.gap; verticalCenter: parent.verticalCenter }
                        spacing: Tokens.gap
                        Item { width: Tokens.islandHeight; height: width; anchors.verticalCenter: parent.verticalCenter
                               Icon { anchors.centerIn: parent; name: modelData.icon || "code"; color: Colors.accent2 } }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: lists.width - Tokens.islandHeight * 4.6
                            Label { width: parent.width; text: modelData.name || modelData.id; font.weight: Font.Medium }
                            Label { width: parent.width; text: modelData.command || ""; role: "dim"; size: Tokens.textSmall; font.family: "monospace" }
                        }
                    }
                    Row {
                        anchors { right: parent.right; rightMargin: Tokens.gap * 0.6; verticalCenter: parent.verticalCenter }
                        spacing: 2
                        SmallButton { icon: "add"; onClicked: WidgetEditor.addType("script:" + modelData.id, tab.screenName, tab.barSpace) }
                        SmallButton { icon: "edit"; onClicked: tab.editing = Object.assign({}, modelData) }
                        SmallButton { icon: "trash"; onClicked: { WidgetEditor.dropType("script:" + modelData.id); CustomWidgets.deleteScript(modelData.id); } }
                    }
                }
            }
            GlassButton { icon: "add"; label: "New script widget"; primary: true; height: Tokens.islandHeight * 1.1; onClicked: tab.newScript() }

            Item { width: 1; height: Tokens.gap }
            Label { text: "QML widgets"; font.weight: Font.DemiBold }
            Label { width: parent.width; wrapMode: Text.WordWrap; elide: Text.ElideNone; role: "dim"; size: Tokens.textSmall + 1
                    text: "Folders in ~/.config/vitrum/widgets with a manifest.json and a Widget.qml. Saving the file reloads the widget." }
            Repeater {
                model: Object.keys(CustomWidgets.qml)
                delegate: Rectangle {
                    required property string modelData
                    readonly property var m: CustomWidgets.qml[modelData]
                    width: lists.width; height: Tokens.islandHeight * 1.8; radius: Tokens.radiusTile
                    color: Colors.alpha(Colors.text, Colors.dark ? 0.055 : 0.04)
                    Row {
                        anchors { left: parent.left; leftMargin: Tokens.gap; verticalCenter: parent.verticalCenter }
                        spacing: Tokens.gap
                        Icon { name: m.icon; color: Colors.accent2; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Label { text: m.name; font.weight: Font.Medium }
                            Label { text: modelData + "/"; role: "dim"; size: Tokens.textSmall }
                        }
                    }
                    SmallButton { anchors { right: parent.right; rightMargin: Tokens.gap * 0.6; verticalCenter: parent.verticalCenter }
                                  icon: "add"; onClicked: WidgetEditor.addType("qml:" + modelData, tab.screenName, tab.barSpace) }
                }
            }
            Row {
                spacing: Tokens.gap
                GlassButton { icon: "folder"; label: "Open folder"; height: Tokens.islandHeight * 1.1; onClicked: Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && exec xdg-open "$1"', "_", CustomWidgets.dir]) }
                GlassButton { icon: "refresh"; label: "Reload"; height: Tokens.islandHeight * 1.1; onClicked: CustomWidgets.reload() }
            }
        }
    }

    // ------------------------------------------------------------- form ---
    Flickable {
        anchors.fill: parent
        visible: !!tab.editing
        contentHeight: form.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: form
            width: parent.width
            spacing: Tokens.gap
            // The preview: the widget itself, running the command as it stands.
            Item {
                width: parent.width
                height: width * 160 / 336
                Surface { anchors.fill: parent; group: "widgets"; radius: Tokens.radiusPanel * 1.25 }
                ScriptWidget {
                    anchors { fill: parent; margins: Tokens.padding }
                    def: tab.editing
                    live: !!tab.editing
                    sizeClass: "M"
                }
            }
            Label { text: "Name"; font.weight: Font.Medium }
            Field { id: nameField; width: parent.width; text: tab.editing ? tab.editing.name : ""; onCommitted: v => tab.put("name", v) }
            Label { text: "Command"; font.weight: Font.Medium }
            Rectangle {
                width: parent.width; height: Math.max(Tokens.islandHeight * 2.4, cmd.contentHeight + Tokens.gap * 2)
                radius: Tokens.radiusButton; color: Colors.alpha(Colors.text, 0.07)
                border.width: cmd.activeFocus ? 2 : 0; border.color: Colors.accent
                TextEdit {
                    id: cmd
                    anchors { fill: parent; margins: Tokens.gap }
                    text: tab.editing ? tab.editing.command : ""
                    font.family: "monospace"; font.pixelSize: Tokens.textSmall + 1
                    color: Colors.text; selectionColor: Colors.accent; wrapMode: TextEdit.WrapAnywhere
                    onActiveFocusChanged: if (!activeFocus && tab.editing && text !== tab.editing.command) tab.put("command", text)
                }
            }
            Label { width: parent.width; text: "Prints a value, then a subtitle, then items — or JSON: {\"value\":\"42\",\"unit\":\"%\",\"progress\":0.42,\"items\":[…],\"history\":[…]}"
                    role: "dim"; size: Tokens.textSmall; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            Label { text: "Show as"; font.weight: Font.Medium }
            Flow {
                width: parent.width; spacing: 6
                Repeater {
                    model: tab.templates
                    delegate: GlassChoice { required property var modelData; label: modelData.l; chosen: !!tab.editing && tab.editing.template === modelData.v; onClicked: tab.put("template", modelData.v) }
                }
            }
            Label { text: "Every"; font.weight: Font.Medium }
            Flow {
                width: parent.width; spacing: 6
                Repeater {
                    model: [1, 2, 5, 10, 30, 60, 300, 900]
                    delegate: GlassChoice { required property int modelData; label: modelData < 60 ? modelData + " s" : modelData / 60 + " min"
                                            chosen: !!tab.editing && Number(tab.editing.interval) === modelData; onClicked: tab.put("interval", modelData) }
                }
            }
            Label { text: "Icon"; font.weight: Font.Medium }
            Flow {
                width: parent.width; spacing: 4
                Repeater {
                    model: tab.icons
                    delegate: GlassChoice {
                        required property string modelData
                        icon: modelData; outlined: false
                        chosen: !!tab.editing && tab.editing.icon === modelData
                        onClicked: tab.put("icon", modelData)
                    }
                }
            }
            Row {
                spacing: Tokens.gap
                GlassButton { label: "Back"; height: Tokens.islandHeight * 1.1; onClicked: tab.editing = null }
                GlassButton {
                    label: "Save"; primary: true
                    height: Tokens.islandHeight * 1.1
                    onClicked: {
                        // What the fields hold now, committed or not.
                        const e = Object.assign({}, tab.editing);
                        e.name = nameField.text || e.name;
                        e.command = cmd.text;
                        CustomWidgets.saveScript(e);
                        tab.editing = null;
                    }
                }
            }
        }
    }

    // A row's quiet icon button: glass without a rim.
    component SmallButton: GlassButton {
        width: Tokens.islandHeight * 1.05; height: width
        outlined: false
    }
    component Field: Rectangle {
        id: fld
        property alias text: input.text
        signal committed(string value)
        height: Tokens.islandHeight * 1.1; radius: Tokens.radiusButton
        color: Colors.alpha(Colors.text, 0.07)
        border.width: input.activeFocus ? 2 : 0; border.color: Colors.accent
        TextInput {
            id: input
            anchors { fill: parent; leftMargin: Tokens.gap; rightMargin: Tokens.gap }
            verticalAlignment: TextInput.AlignVCenter
            font.family: Tokens.fontText; font.pixelSize: Tokens.textSize
            color: Colors.text; selectionColor: Colors.accent; clip: true
            onAccepted: fld.committed(text)
            onActiveFocusChanged: if (!activeFocus) fld.committed(text)
        }
    }
}
