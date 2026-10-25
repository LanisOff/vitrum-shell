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
                    // The current app, a glass button that opens the choices.
                    Surface {
                        visible: kind.modelData.apps.length > 0
                        anchors.verticalCenter: parent.verticalCenter
                        height: Tokens.islandHeight * 1.1
                        width: pickRow.implicitWidth + Tokens.padding * 1.2
                        group: "panels"; level: 1; radius: Tokens.radiusButton
                        Rectangle {
                            anchors.fill: parent; radius: parent.radius
                            color: Colors.alpha(Colors.text, pm.containsMouse || kind.expanded ? 0.06 : 0)
                            Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
                        }
                        Row {
                            id: pickRow
                            anchors.centerIn: parent
                            spacing: Tokens.gap / 2
                            IconImage { visible: !!kind.current; implicitSize: Tokens.iconSize; anchors.verticalCenter: parent.verticalCenter
                                        source: kind.current ? Apps.iconSource(kind.current.icon) : ""
                                        Icon { anchors.centerIn: parent; visible: parent.source == ""; name: "window"; size: Math.round(parent.width * 0.8); color: Colors.textDim } }
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
                            // Run first: closing the choices destroys this chip, and its
                            // handler loses `page` and `modelData` midway.
                            onPicked: { page.run(["default", kind.modelData.kind, modelData.id]); page.open_ = ""; }
                        }
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
