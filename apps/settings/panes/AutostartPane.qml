import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components
import qs.common

// What starts with the session (XDG autostart: ~/.config/autostart over
// /etc/xdg/autostart), through vitrum-apps; every change reloads the list.
Page {
    id: page
    title: "Autostart"
    subtitle: "Apps that start when you log in, a moment after the desktop is up. They come from ~/.config/autostart and /etc/xdg/autostart."

    property var data_: ({ defaults: [], autostart: [], apps: [] })
    property bool loaded: false
    property string failed: ""

    Process {
        id: lister
        running: true
        command: ["vitrum-apps", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) { page.failed = "vitrum-apps is missing or failed — run ./install.sh --only shell."; return; }
                try { page.data_ = JSON.parse(text); page.loaded = true; } catch (e) { page.failed = "vitrum-apps gave nothing to read."; }
            }
        }
    }
    Command { id: action }
    function run(args) {
        action.exec(["vitrum-apps"].concat(args), "", (code, out, err) => {
            page.failed = code === 0 ? "" : (err.trim() || "That did not work.");
            lister.running = true;
        });
    }

    Label { visible: !page.loaded && !page.failed; text: "Reading the apps…"; role: "dim" }
    Label { visible: page.failed.length > 0; text: page.failed; role: "danger"; width: parent.width; wrapMode: Text.WordWrap }

    Section {
        id: startup
        title: "Open at login"
        visible: page.loaded
        note: "Turning off an entry that came with the system writes a copy into ~/.config/autostart that says so; the original stays."
        property bool adding: false
        property string filter: ""
        Label { visible: page.data_.autostart.length === 0; text: "Nothing starts with the session yet."; role: "dim"; padding: Tokens.padding }
        Repeater {
            model: page.data_.autostart
            delegate: SettingRow {
                id: entry
                required property var modelData
                label: modelData.name
                hint: modelData.managed ? "Not started: " + modelData.managed + "." : modelData.comment
                leading: Quickshell.iconPath(modelData.icon || "application-x-executable", "application-x-executable")
                Icon {
                    visible: entry.modelData.user && !entry.modelData.system
                    name: "trash"; color: Colors.textDim; anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: page.run(["autostart", "remove", entry.modelData.id]) }
                }
                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: entry.modelData.managed ? 0.4 : 1
                    checked: entry.modelData.enabled && !entry.modelData.managed
                    onToggled: if (!entry.modelData.managed) page.run(["autostart", entry.modelData.enabled ? "off" : "on", entry.modelData.id])
                }
            }
        }
        SettingRow {
            label: "Add an app"
            divider: startup.adding
            Capsule { icon: startup.adding ? "close" : "add"; label: startup.adding ? "Close" : "Choose…"
                      onClicked: { startup.adding = !startup.adding; startup.filter = ""; if (startup.adding) addField.takeFocus(); } }
        }
        Column {
            visible: startup.adding
            x: Tokens.padding; width: parent.width - Tokens.padding * 2
            topPadding: Tokens.gap / 2; bottomPadding: Tokens.gap
            spacing: Tokens.gap
            Field { id: addField; width: parent.width; placeholder: "Search apps"; onTextChanged: startup.filter = text.toLowerCase() }
            Flow {
                width: parent.width
                spacing: Tokens.gap / 2
                Repeater {
                    model: startup.adding ? page.data_.apps.filter(a => !page.data_.autostart.some(s => s.id === a.id)
                                                                        && (!startup.filter || a.name.toLowerCase().indexOf(startup.filter) >= 0)).slice(0, 24) : []
                    delegate: AppChip {
                        required property var modelData
                        app: modelData
                        onPicked: { startup.adding = false; page.run(["autostart", "add", modelData.id]); }
                    }
                }
            }
        }
    }

    // An app to pick: its icon and name; the chosen one in the accent.
    component AppChip: Rectangle {
        id: chip
        property var app: ({})
        property bool on: false
        signal picked()
        height: Tokens.islandHeight * 1.15; radius: height / 2
        width: chipRow.implicitWidth + Tokens.padding * 1.2
        color: on ? Colors.accent : Colors.alpha(Colors.text, cm.containsMouse ? 0.1 : 0.05)
        Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
        scale: cm.pressed ? 0.94 : 1
        Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.bouncy } }
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: Tokens.gap / 2
            IconImage { implicitSize: Tokens.iconSize; anchors.verticalCenter: parent.verticalCenter; source: Quickshell.iconPath(chip.app.icon || "application-x-executable", "application-x-executable") }
            Label { text: chip.app.name || ""; role: chip.on ? "onAccent" : "text"; size: Tokens.textSmall + 1; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.picked() }
    }
}
