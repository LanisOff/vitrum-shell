import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components
import qs.common

// Which app opens links and files (mimeapps.list), through vitrum-apps; every
// change reloads the list. What starts with the session is Autostart's.
Page {
    id: page
    title: "Applications"
    subtitle: "Default apps open links and files from anywhere — the browser, the file manager, xdg-open."

    property var data_: ({ defaults: [], autostart: [], apps: [] })
    property bool loaded: false
    property string open_: ""              // the kind whose choices are showing
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
        title: "Default apps"
        visible: page.loaded
        Repeater {
            model: page.data_.defaults
            delegate: Column {
                id: kind
                required property var modelData
                required property int index
                width: parent.width
                readonly property var current: modelData.apps.find(a => a.id === modelData.current) || null
                readonly property bool expanded: page.open_ === modelData.kind
                SettingRow {
                    label: kind.modelData.label
                    hint: kind.modelData.apps.length === 0 ? "No installed app handles this."
                          : kind.modelData.mixed ? "Some of these open in another app; pick one for all of them." : ""
                    divider: kind.expanded || kind.index < page.data_.defaults.length - 1
                    Rectangle {
                        visible: kind.modelData.apps.length > 0
                        anchors.verticalCenter: parent.verticalCenter
                        height: Tokens.islandHeight * 1.1; radius: height / 2
                        width: pickRow.implicitWidth + Tokens.padding * 1.2
                        color: Colors.alpha(Colors.text, pm.containsMouse || kind.expanded ? 0.1 : 0.06)
                        Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
                        Row {
                            id: pickRow
                            anchors.centerIn: parent
                            spacing: Tokens.gap / 2
                            IconImage { visible: !!kind.current; implicitSize: Tokens.iconSize; anchors.verticalCenter: parent.verticalCenter
                                        source: kind.current ? Quickshell.iconPath(kind.current.icon || "application-x-executable", "application-x-executable") : "" }
                            Label { text: kind.current ? kind.current.name : "Not set"; role: kind.current ? "text" : "dim"; anchors.verticalCenter: parent.verticalCenter }
                            Icon { name: "chevron"; size: Tokens.iconSize * 0.8; color: Colors.textDim; anchors.verticalCenter: parent.verticalCenter
                                   rotation: kind.expanded ? 90 : 0; Behavior on rotation { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } } }
                        }
                        MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: page.open_ = kind.expanded ? "" : kind.modelData.kind }
                    }
                }
                // The choices: every app that handles it, the current one marked.
                // Picking the current one again sets it for every type of the kind.
                Flow {
                    visible: kind.expanded
                    x: Tokens.padding; width: parent.width - Tokens.padding * 2
                    topPadding: Tokens.gap / 2; bottomPadding: Tokens.gap
                    spacing: Tokens.gap / 2
                    Repeater {
                        model: kind.expanded ? kind.modelData.apps : []
                        delegate: AppChip {
                            required property var modelData
                            app: modelData
                            on: modelData.id === kind.modelData.current
                            onPicked: { page.open_ = ""; page.run(["default", kind.modelData.kind, modelData.id]); }
                        }
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
