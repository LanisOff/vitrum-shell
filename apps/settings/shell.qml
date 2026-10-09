//@ pragma AppId vitrum-settings
//@ pragma Env VITRUM_NO_THEME=1
//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import qs.common
import "lib/settingsui.js" as Ui
import "lib/settings-panes.js" as Panes

/*
 * Settings. A sidebar of panes, a search over pane names and every setting's
 * label, and one pane at a time. Panes read and write through the shell's
 * Settings service, so the shell applies each change as it is made.
 *
 *   vitrum-settings --pane dock      opens on a pane (VITRUM_PANE)
 */
ShellRoot {
    id: app

    // The sections, their search keys and old ids: shared with Spotlight.
    readonly property var panes: Panes.panes

    property string current: Panes.resolve(Quickshell.env("VITRUM_PANE") || "")
    property string query: ""

    readonly property var allKeys: Ui.leafKeys(Settings.defaults)
    function matches(p) { return Panes.matches(p, query, allKeys, Ui.label); }
    readonly property var shown: panes.filter(matches)
    onShownChanged: if (shown.length && !shown.some(p => p.id === current)) current = shown[0].id

    // qs ipc call settings pane dock — switch the open window to a pane.
    IpcHandler {
        target: "settings"
        function pane(id: string): void { if (Panes.known(id)) { app.query = ""; app.current = Panes.resolve(id); } }
        function current(): string { return app.current; }
        /// Tests: type into the search; → the sections left in the sidebar.
        function search(q: string): string { app.query = q; return app.shown.map(p => p.id).join(","); }
        /// Tests: set one key through the app (what any control does).
        function set(key: string, value: string): void { Settings.set(key, value); }
    }

    AppWindow {
        appTitle: "Settings"
        implicitWidth: 1040
        implicitHeight: 700

        Row {
            anchors.fill: parent
            // ------------------------------------------------- sidebar ---
            Item {
                id: side
                width: 250
                height: parent.height
                Column {
                    anchors { fill: parent; margins: Tokens.padding }
                    spacing: Tokens.gap
                    Rectangle {
                        width: parent.width; height: Tokens.islandHeight * 1.2; radius: height / 2
                        color: Colors.alpha(Colors.text, 0.06)
                        border.width: search.activeFocus ? 2 : 0; border.color: Colors.accent
                        Row {
                            anchors { fill: parent; leftMargin: Tokens.gap; rightMargin: Tokens.gap }
                            spacing: Tokens.gap / 2
                            Icon { name: "search"; color: Colors.textDim; anchors.verticalCenter: parent.verticalCenter; size: Tokens.iconSize * 0.9 }
                            TextInput {
                                id: search
                                width: parent.width - Tokens.iconSize * 1.5
                                anchors.verticalCenter: parent.verticalCenter
                                font.family: Tokens.fontText; font.pixelSize: Tokens.textSize
                                color: Colors.text; clip: true
                                onTextChanged: app.query = text
                                Keys.onEscapePressed: e => { if (text) { text = ""; e.accepted = true; } else e.accepted = false; }
                                Label { visible: !search.text; text: "Search settings"; role: "dim"; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }
                    Flickable {
                        width: parent.width
                        height: parent.height - Tokens.islandHeight * 1.2 - Tokens.gap
                        contentHeight: list.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        // The current pane's highlight: one plate that springs to the pane chosen.
                        Rectangle {
                            readonly property Item entry: {
                                sideRep.count;
                                const i = app.shown.findIndex(p => p.id === app.current);
                                const d = i >= 0 ? sideRep.itemAt(i) : null;
                                return d ? d.children[1] : null;
                            }
                            visible: entry !== null
                            y: entry ? entry.parent.y + entry.y : 0
                            width: list.width
                            height: entry ? entry.height : 0
                            radius: Tokens.radiusInner
                            color: Colors.accent
                            Behavior on y { enabled: Motion.enabled; SpringAnim { token: Motion.bouncy } }
                        }
                        Column {
                            id: list
                            width: parent.width
                            spacing: 2
                            Repeater {
                                id: sideRep
                                model: app.shown
                                delegate: Column {
                                    required property var modelData
                                    required property int index
                                    width: list.width
                                    readonly property bool first: index === 0 || app.shown[index - 1].group !== modelData.group
                                    Label { visible: parent.first; text: modelData.group; role: "dim"; size: Tokens.textSmall; font.weight: Font.DemiBold
                                            topPadding: index === 0 ? 0 : Tokens.gap; bottomPadding: 4; leftPadding: Tokens.gap }
                                    Rectangle {
                                        width: list.width; height: Tokens.islandHeight * 1.25; radius: Tokens.radiusInner
                                        readonly property bool on: app.current === modelData.id
                                        color: !on && m.containsMouse ? Colors.alpha(Colors.text, 0.08) : "transparent"
                                        Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
                                        Row {
                                            // Leans towards the pointer.
                                            anchors { fill: parent; leftMargin: Tokens.gap + (m.containsMouse && !parent.on ? 5 : 0) }
                                            Behavior on anchors.leftMargin { enabled: Motion.enabled; SpringAnim { token: Motion.bouncy } }
                                            spacing: Tokens.gap
                                            Icon { name: modelData.icon; anchors.verticalCenter: parent.verticalCenter; color: parent.parent.on ? Colors.onAccent : Colors.text }
                                            Label { text: modelData.name; anchors.verticalCenter: parent.verticalCenter; role: parent.parent.on ? "onAccent" : "text" }
                                        }
                                        MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: app.current = modelData.id }
                                    }
                                }
                            }
                            Label { visible: app.shown.length === 0; text: "Nothing matches"; role: "dim"; leftPadding: Tokens.gap }
                        }
                    }
                }
            }
            Rectangle { width: 1; height: parent.height; color: Colors.alpha(Colors.text, 0.08) }
            // --------------------------------------------------- pane ---
            Column {
            width: parent.width - side.width - 1
            height: parent.height
            // The settings file does not parse: nothing can be saved until it is fixed.
            Rectangle {
                id: broken
                visible: !!Settings.error
                width: parent.width
                height: visible ? bl.implicitHeight + Tokens.padding * 1.4 : 0
                color: Colors.alpha(Colors.danger, 0.18)
                Label {
                    id: bl
                    anchors { left: parent.left; right: fixBtn.left; verticalCenter: parent.verticalCenter; leftMargin: Tokens.padding; rightMargin: Tokens.gap }
                    wrapMode: Text.WordWrap; elide: Text.ElideNone
                    text: "settings.json could not be read, so changes here are not saved. Fix the file in Advanced (the desktop keeps its last good settings)."
                }
                Rectangle {
                    id: fixBtn
                    anchors { right: parent.right; rightMargin: Tokens.padding; verticalCenter: parent.verticalCenter }
                    height: Tokens.islandHeight * 1.05; radius: height / 2; width: fl.implicitWidth + Tokens.padding * 1.6
                    color: Colors.danger
                    Label { id: fl; anchors.centerIn: parent; text: "Open Advanced"; color: "white"; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: app.current = "advanced" }
                }
            }
            Loader {
                id: pane
                width: parent.width
                height: parent.height - broken.height
                source: Panes.paneFile(app.current)
                opacity: status === Loader.Ready ? 1 : 0
                Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
            }
            }
        }
    }
}
