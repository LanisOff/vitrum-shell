import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.components
import "../../lib/keybinds.js" as Lib

/*
 * Every keybind, on Mod+/: the sections of KEYBINDS.md in columns, each bind
 * with its keys as caps. Typing filters — by what a bind does, its section, or
 * the keys ("super q"). Escape, Mod+/ again or a click outside closes it.
 *
 * Reads ~/.config/vitrum/binds.json, which the installer writes from
 * KEYBINDS.md together with niri's binds, so the sheet is the keymap; and
 * tmux-binds.json (vitrum-theme), tmux's keys as chosen at install; and
 * overrides.kdl, the user's own binds, live.
 */
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property bool open: UiState.keybinds && screen.name === (Niri.focusedOutput || Quickshell.screens[0].name)

    visible: true
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "vitrum-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: root.open ? catcher : dot }
    BlurKick { id: blurKick; window: root }
    BackgroundEffect.blurRegion: Materials.wantsRegion("overlay") && !blurKick.on ? effect : blurKick.none
    Region { id: effect; item: root.open || card.opacity > 0 ? shape : dot; radius: Tokens.radiusPanel }
    Item { id: dot; width: 1; height: 1 }
    Item { id: shape; x: card.x + (card.width - card.width * card.scale) / 2; y: card.y + (card.height - card.height * card.scale) / 2; width: card.width * card.scale; height: card.height * card.scale }

    // ------------------------------------------------------------- data ---
    property var desktopBinds: []
    property var tmuxBinds: []
    property var ownBinds: []
    // The keymap with the user's own binds over it, then tmux.
    readonly property var binds: Lib.mergeBinds(desktopBinds, ownBinds).concat(tmuxBinds)
    // overrides.kdl: binds added there work as soon as niri reloads, so the
    // sheet reads it too (and again whenever it changes).
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/vitrum/niri/overrides.kdl"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.ownBinds = Lib.parseKdlBinds(text())
        onLoadFailed: root.ownBinds = []
    }
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/vitrum/binds.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.desktopBinds = JSON.parse(text()); } catch (e) { root.desktopBinds = []; } }
    }
    // tmux's keys as chosen at install (vitrum's or tmux's own); absent without tmux.
    FileView {
        path: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/vitrum/tmux-binds.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.tmuxBinds = JSON.parse(text()); } catch (e) { root.tmuxBinds = []; } }
        onLoadFailed: root.tmuxBinds = []
    }
    property string query: ""
    readonly property var sections: Lib.group(binds, query)

    onOpenChanged: if (open) { query = ""; search.text = ""; search.forceActiveFocus(); list.contentY = 0; }

    // ----------------------------------------------------------- surface ---
    Rectangle {
        id: dim
        anchors.fill: parent
        color: Colors.alpha("#000000", root.open ? 0.35 : 0)
        Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.standard } }
    }
    MouseArea { id: catcher; anchors.fill: parent; onClicked: UiState.keybinds = false }

    Surface {
        id: card
        group: "overlay"
        readonly property real colW: Tokens.islandHeight * 12
        readonly property int cols: Math.max(1, Math.min(4, Math.floor((root.width * 0.86 - 2 * Tokens.padding) / (colW + Tokens.gap * 2))))
        width: cols * colW + (cols - 1) * Tokens.gap * 2 + 2 * Tokens.padding * 1.5
        height: Math.min(root.height * 0.84, header.height + Tokens.gap * 2 + list.contentHeight + 2 * Tokens.padding * 1.5)
        anchors.centerIn: parent
        radius: Tokens.radiusPanel
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.96
        visible: opacity > 0
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
        Behavior on scale { enabled: Motion.enabled; NumberAnimation { duration: Motion.standard; easing.type: Easing.OutQuint } }
        Behavior on height { enabled: Motion.enabled && root.open; NumberAnimation { duration: Motion.standard; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }   // clicks inside do not close

        // Title and search.
        Item {
            id: header
            x: Tokens.padding * 1.5; y: Tokens.padding * 1.5
            width: card.width - 2 * x
            height: Tokens.islandHeight * 1.3
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.gap
                Icon { name: "keyboard"; size: Tokens.iconSize * 1.2; anchors.verticalCenter: parent.verticalCenter }
                Label { text: "Keybinds"; size: Tokens.textLarge; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
            }
            Surface {
                group: "overlay"
                level: 1
                outlined: false
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: Math.min(Tokens.islandHeight * 10, parent.width * 0.5)
                height: parent.height
                radius: height / 2
                Row {
                    anchors { fill: parent; leftMargin: Tokens.padding; rightMargin: Tokens.padding }
                    spacing: Tokens.gap
                    Icon { id: sicon; name: "search"; color: Colors.textDim; anchors.verticalCenter: parent.verticalCenter }
                    TextInput {
                        id: search
                        width: parent.width - sicon.width - Tokens.gap
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.text
                        font.family: Tokens.fontText
                        font.pixelSize: Tokens.textSize
                        selectionColor: Colors.accent
                        clip: true
                        focus: root.open
                        onTextChanged: root.query = text
                        Keys.onEscapePressed: { if (text) text = ""; else UiState.keybinds = false; }
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Down || event.key === Qt.Key_PageDown) { list.flick(0, -2000); event.accepted = true; }
                            else if (event.key === Qt.Key_Up || event.key === Qt.Key_PageUp) { list.flick(0, 2000); event.accepted = true; }
                        }
                        Label { visible: !search.text; text: "Search: what it does, or keys (super q)"; role: "dim"; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }

        // The sections, in columns.
        Flickable {
            id: list
            x: Tokens.padding * 1.5
            y: header.y + header.height + Tokens.gap * 2
            width: card.width - 2 * x
            height: card.height - y - Tokens.padding * 1.5
            contentWidth: width
            contentHeight: flow.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Flow {
                id: flow
                width: list.width
                spacing: Tokens.gap * 2
                Repeater {
                    model: root.sections
                    delegate: Column {
                        id: section
                        required property var modelData
                        width: card.colW
                        spacing: Tokens.gap * 0.4
                        Label {
                            text: section.modelData.section.toUpperCase()
                            role: "accent"
                            size: Tokens.textSmall
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.2
                            bottomPadding: Tokens.gap * 0.4
                        }
                        Repeater {
                            model: section.modelData.rows
                            delegate: Item {
                                id: row
                                required property var modelData
                                width: section.width
                                height: Math.max(caps.height, title.implicitHeight) + Tokens.gap * 0.5
                                Label {
                                    id: title
                                    anchors { left: parent.left; right: caps.left; rightMargin: Tokens.gap; verticalCenter: parent.verticalCenter }
                                    text: row.modelData.title
                                    elide: Text.ElideRight
                                }
                                // Every key set for this action: "Super ←  or  Super H".
                                Row {
                                    id: caps
                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                    spacing: Tokens.gap * 0.6
                                    Repeater {
                                        model: row.modelData.alts
                                        delegate: Row {
                                            id: alt
                                            required property var modelData
                                            required property int index
                                            spacing: 3
                                            Label { visible: alt.index > 0; text: "or"; role: "dim"; size: Tokens.textSmall; anchors.verticalCenter: parent.verticalCenter; rightPadding: 3 }
                                            Repeater {
                                                model: alt.modelData
                                                delegate: Rectangle {
                                                    required property string modelData
                                                    readonly property bool then: modelData === "›"
                                                    height: Tokens.textSize * 1.7
                                                    width: then ? thenLabel.implicitWidth : Math.max(height, capLabel.implicitWidth + Tokens.gap * 1.2)
                                                    radius: Tokens.radiusInner * 0.7
                                                    color: then ? "transparent" : Colors.alpha(Colors.text, 0.08)
                                                    border.width: then ? 0 : 1
                                                    border.color: Colors.alpha(Colors.text, 0.14)
                                                    Label { id: capLabel; visible: !parent.then; anchors.centerIn: parent; text: parent.modelData; size: Tokens.textSmall; font.weight: Font.DemiBold }
                                                    Label { id: thenLabel; visible: parent.then; anchors.centerIn: parent; text: "›"; role: "dim" }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        Label {
            anchors.centerIn: list
            visible: root.sections.length === 0
            text: root.binds.length ? "No keybind matches “" + root.query + "”" : "No binds.json yet — run ./install.sh --only session"
            role: "dim"
        }
    }
}
