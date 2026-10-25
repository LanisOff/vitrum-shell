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
                leading: Apps.iconSource(modelData.icon)
                leadingGlyph: "window"      // when the theme has no icon for it
                Icon {
                    visible: entry.modelData.user && !entry.modelData.system
                    name: "trash"; color: Colors.textDim; anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: page.run(["autostart", "remove", entry.modelData.id]) }
                }
                GlassSwitch {
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
            GlassButton { icon: startup.adding ? "close" : "add"; label: startup.adding ? "Close" : "Choose…"
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
                        // Run first: closing the picker destroys this chip, and its
                        // handler loses `page` and `modelData` midway.
                        onPicked: { page.run(["autostart", "add", modelData.id]); startup.adding = false; }
                    }
                }
            }
        }
    }

    // An app to pick: its icon and name on glass; the chosen one tinted.
    component AppChip: Item {
        id: chip
        property var app: ({})
        property bool on: false
        signal picked()
        height: Tokens.islandHeight * 1.15
        width: chipRow.implicitWidth + Tokens.padding * 1.2
        scale: cm.pressed ? 0.97 : 1
        Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
        Surface { anchors.fill: parent; group: "panels"; level: 1; radius: Tokens.radiusTile }
        // The lift under the pointer, on clear glass.
        Rectangle {
            anchors.fill: parent; radius: Tokens.radiusTile
            color: Colors.alpha(Colors.text, !chip.on && cm.containsMouse ? 0.06 : 0)
            Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
        }
        ShellTint { anchors.fill: parent; radius: Tokens.radiusTile; active: chip.on; hovered: cm.containsMouse }
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: Tokens.gap / 2
            IconImage { implicitSize: Tokens.iconSize; anchors.verticalCenter: parent.verticalCenter; source: Apps.iconSource(chip.app.icon)
                        Icon { anchors.centerIn: parent; visible: parent.source == ""; name: "window"; size: Math.round(parent.width * 0.8); color: Colors.textDim } }
            Label { text: chip.app.name || ""; size: Tokens.textSmall + 1; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.picked() }
    }
}
