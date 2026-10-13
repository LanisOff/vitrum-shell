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
                    width: lists.width; height: Tokens.islandHeight * 2.1; radius: 18
                    color: Colors.alpha(Colors.text, Colors.dark ? 0.055 : 0.04)
                    Row {
                        anchors { left: parent.left; leftMargin: Tokens.gap; verticalCenter: parent.verticalCenter }
                        spacing: Tokens.gap
                        Rectangle { width: Tokens.islandHeight; height: width; radius: width / 2; color: Colors.alpha(Colors.accent, 0.2); anchors.verticalCenter: parent.verticalCenter
                                    Icon { anchors.centerIn: parent; name: modelData.icon || "code"; color: Colors.accent; filled: true } }
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
                        SmallButton { icon: "trash"; onClicked: CustomWidgets.deleteScript(modelData.id) }
                    }
                }
            }
            Pill { icon: "add"; text: "New script widget"; filled: true; onClicked: tab.newScript() }

            Item { width: 1; height: Tokens.gap }
            Label { text: "QML widgets"; font.weight: Font.DemiBold }
            Label { width: parent.width; wrapMode: Text.WordWrap; elide: Text.ElideNone; role: "dim"; size: Tokens.textSmall + 1
                    text: "Folders in ~/.config/vitrum/widgets with a manifest.json and a Widget.qml. Saving the file reloads the widget." }
            Repeater {
                model: Object.keys(CustomWidgets.qml)
                delegate: Rectangle {
                    required property string modelData
                    readonly property var m: CustomWidgets.qml[modelData]
                    width: lists.width; height: Tokens.islandHeight * 1.8; radius: 18
                    color: Colors.alpha(Colors.text, Colors.dark ? 0.055 : 0.04)
                    Row {
                        anchors { left: parent.left; leftMargin: Tokens.gap; verticalCenter: parent.verticalCenter }
                        spacing: Tokens.gap
                        Icon { name: m.icon; color: Colors.accent; filled: true; anchors.verticalCenter: parent.verticalCenter }
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
                Pill { icon: "folder"; text: "Open folder"; onClicked: Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && exec xdg-open "$1"', "_", CustomWidgets.dir]) }
                Pill { icon: "refresh"; text: "Reload"; onClicked: CustomWidgets.reload() }
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
                radius: Tokens.radiusInner; color: Colors.alpha(Colors.text, 0.07)
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
                    delegate: Choice { required property var modelData; text: modelData.l; on: tab.editing && tab.editing.template === modelData.v; onClicked: tab.put("template", modelData.v) }
                }
            }
            Label { text: "Every"; font.weight: Font.Medium }
            Flow {
                width: parent.width; spacing: 6
                Repeater {
                    model: [1, 2, 5, 10, 30, 60, 300, 900]
                    delegate: Choice { required property int modelData; text: modelData < 60 ? modelData + " s" : modelData / 60 + " min"
                                       on: tab.editing && Number(tab.editing.interval) === modelData; onClicked: tab.put("interval", modelData) }
                }
            }
            Label { text: "Icon"; font.weight: Font.Medium }
            Flow {
                width: parent.width; spacing: 4
                Repeater {
                    model: tab.icons
                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool on: tab.editing && tab.editing.icon === modelData
                        width: Tokens.islandHeight; height: width; radius: width / 2
                        color: on ? Colors.alpha(Colors.accent, Colors.dark ? 0.32 : 0.22) : icMouse.containsMouse ? Colors.alpha(Colors.text, 0.08) : "transparent"
                        Icon { anchors.centerIn: parent; name: modelData; color: on ? Colors.accent : Colors.text }
                        MouseArea { id: icMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tab.put("icon", modelData) }
                    }
                }
            }
            Row {
                spacing: Tokens.gap
                Pill { text: "Back"; onClicked: tab.editing = null }
                Pill {
                    text: "Save"; filled: true
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

    component SmallButton: Rectangle {
        id: sb
        property string icon: ""
        signal clicked()
        width: Tokens.islandHeight * 1.05; height: width; radius: width / 2
        color: sbMouse.containsMouse ? Colors.alpha(Colors.text, 0.12) : "transparent"
        Icon { anchors.centerIn: parent; name: sb.icon }
        MouseArea { id: sbMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sb.clicked() }
    }
    component Pill: Rectangle {
        id: pl
        property string icon: ""
        property string text: ""
        property bool filled: false
        signal clicked()
        height: Tokens.islandHeight * 1.1; radius: height / 2
        width: plRow.implicitWidth + Tokens.padding * 2
        color: filled ? Colors.accent : plMouse.containsMouse ? Colors.alpha(Colors.accent, 0.3) : Colors.alpha(Colors.accent, Colors.dark ? 0.2 : 0.14)
        Row { id: plRow; anchors.centerIn: parent; spacing: 6
              Icon { visible: pl.icon !== ""; name: pl.icon; color: pl.filled ? Colors.onAccent : Colors.text; anchors.verticalCenter: parent.verticalCenter }
              Label { text: pl.text; font.weight: Font.Medium; role: pl.filled ? "onAccent" : "text"; anchors.verticalCenter: parent.verticalCenter } }
        MouseArea { id: plMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pl.clicked() }
    }
    component Choice: Rectangle {
        id: ch
        property string text: ""
        property bool on: false
        signal clicked()
        height: Tokens.islandHeight; radius: Tokens.radiusInner
        width: chLabel.implicitWidth + Tokens.padding * 1.2
        color: on ? Colors.alpha(Colors.accent, Colors.dark ? 0.32 : 0.22) : chMouse.containsMouse ? Colors.alpha(Colors.text, 0.08) : "transparent"
        border.width: on ? 0 : Tokens.hairline; border.color: Colors.alpha(Colors.text, 0.25)
        Label { id: chLabel; anchors.centerIn: parent; text: ch.text; size: Tokens.textSmall + 1 }
        MouseArea { id: chMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ch.clicked() }
    }
    component Field: Rectangle {
        id: fld
        property alias text: input.text
        signal committed(string value)
        height: Tokens.islandHeight * 1.1; radius: Tokens.radiusInner
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
