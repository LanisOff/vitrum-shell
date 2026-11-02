import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.components
import "../../lib/keybinds.js" as Lib

/*
 * Every keybind, on Mod+/: the essentials, then the sections of KEYBINDS.md in
 * columns, each bind with its keys as caps. Typing filters — by what a bind
 * does, its section, or the keys ("super q") — and holding modifiers leaves the
 * binds that use just those. A click on a bind, or Enter on the first one found,
 * opens it in Settings → Keyboard. Escape, Mod+/ again or a click outside closes it.
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
    readonly property bool open: gate.ready && UiState.keybinds && screen.name === (Niri.focusedOutput || Quickshell.screens[0].name)

    MapGate { id: gate; want: root.open }      // mapped only while open (components/MapGate.qml)
    visible: gate.mapped
    // Mapped again by opening: the window is a new one, the focus goes back in.
    onBackingWindowVisibleChanged: if (backingWindowVisible && open) search.forceActiveFocus()
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "vitrum-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: root.open ? catcher : dot }
    BlurKick { id: blurKick; window: root }
    BackgroundEffect.blurRegion: Materials.wantsRegion("overlay", blurKick.screen) && !blurKick.on ? effect : blurKick.none
    Region { id: effect; item: root.open || card.opacity > 0 ? shape : dot; radius: Tokens.radiusPanel }
    // Off the screen's top-left pixel: the top-left hot corner sits there, under this layer.
    Item { id: dot; x: 2; y: 2; width: 1; height: 1 }
    Item { id: shape; x: card.x + (card.width - card.width * card.scale) / 2; y: card.y + (card.height - card.height * card.scale) / 2; width: card.width * card.scale; height: card.height * card.scale }

    // ------------------------------------------------------------- data ---
    property var desktopBinds: []
    property var tmuxBinds: []
    property var ownBinds: []
    // The keymap with the user's own binds over it, then tmux.
    readonly property var binds: Lib.mergeBinds(Lib.effective(desktopBinds, Settings.get("keybinds.changes", {}), Settings.get("keybinds.own", []))
                                                    .filter(b => !b.off), ownBinds).concat(tmuxBinds)
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
    /// The modifiers held down now: { super, ctrl, alt, shift }.
    property var held: ({})
    readonly property string heldText: query ? "" : Lib.heldLabel(held)
    // Only while nothing is typed: Shift is for capitals too.
    readonly property var sections: Lib.sheet(binds, query, heldText ? held : null)
    readonly property var essentials: sections.length && sections[0].wide ? sections[0] : null
    readonly property var columns: Lib.columns(sections.filter(s => !s.wide), card.cols)
    // Enter takes it, and it is lit to say so.
    readonly property var firstFound: query && sections.length ? sections[0].rows[0] : null

    onOpenChanged: if (open) { query = ""; held = {}; search.text = ""; search.forceActiveFocus(); list.contentY = 0; }

    /// The bind in Settings → Keyboard: the window that is open, else a new one.
    function edit(find) {
        UiState.keybinds = false;
        const w = Niri.windowList.find(x => x.appId === "vitrum-settings");
        if (w) Quickshell.execDetached(["sh", "-c", 'q=$(command -v qs || echo quickshell); "$q" -p "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/vitrum-settings/shell.qml" ipc call settings keybind "$1"; niri msg action focus-window --id "$2"',
                                        "_", find, String(w.id)]);
        else Quickshell.execDetached(["env", "VITRUM_KEY_FIND=" + find, "vitrum-settings", "--pane", "keyboard"]);
    }

    component SectionTitle: Label {
        role: "dim"
        size: Tokens.textSmall
        font.weight: Font.DemiBold
        font.letterSpacing: 1.2
        bottomPadding: Tokens.gap * 0.4
    }

    component BindRow: Item {
        id: row
        required property var bind
        readonly property bool lit: !!root.firstFound && root.firstFound.title === bind.title
        width: card.colW
        height: Math.max(caps.height, title.implicitHeight) + Tokens.gap * 0.5
        // Lit glass, reaching a little past the text.
        Rectangle {
            anchors { fill: parent; leftMargin: -Tokens.gap * 0.5; rightMargin: -Tokens.gap * 0.5 }
            radius: Tokens.radiusButton
            color: Colors.alpha(Colors.text, mouse.containsMouse || row.lit ? 0.09 : 0)
            Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
        }
        Label {
            id: title
            anchors { left: parent.left; right: caps.left; rightMargin: Tokens.gap; verticalCenter: parent.verticalCenter }
            text: row.bind.title
            elide: Text.ElideRight
        }
        // What a click does; over the end of a long title, not taking its room.
        Icon {
            id: pencil
            anchors { right: caps.left; rightMargin: Tokens.gap * 0.6; verticalCenter: parent.verticalCenter }
            name: "edit"; size: Tokens.iconSize * 0.8; color: Colors.textDim
            opacity: mouse.containsMouse || row.lit ? 1 : 0
            Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
        }
        // Every key set for this action: "Super ←  or  Super H".
        Row {
            id: caps
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: Tokens.gap * 0.6
            Repeater {
                model: row.bind.alts
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
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.edit(row.bind.find)
        }
    }

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
                radius: Tokens.radiusTile
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
                        // While a composition is open these keys are the input method's:
                        // Escape cancels it and Enter confirms it, before they mean anything
                        // here. preeditText, not inputMethodComposing: that one stays true
                        // after a cancelled composition (Qt on text-input-v3).
                        Keys.onEscapePressed: e => {
                            if (preeditText) { e.accepted = false; return; }
                            if (text) text = ""; else UiState.keybinds = false;
                        }
                        Keys.onReturnPressed: e => {
                            if (preeditText) { e.accepted = false; return; }
                            if (root.firstFound) root.edit(root.firstFound.find);
                        }
                        Keys.onEnterPressed: e => {
                            if (preeditText) { e.accepted = false; return; }
                            if (root.firstFound) root.edit(root.firstFound.find);
                        }
                        Keys.onReleased: event => root.held = Lib.heldKeys(root.held, event.key, false)
                        Keys.onPressed: event => {
                            root.held = Lib.heldKeys(root.held, event.key, true);
                            if (event.key === Qt.Key_Down || event.key === Qt.Key_PageDown) { list.flick(0, -2000); event.accepted = true; }
                            else if (event.key === Qt.Key_Up || event.key === Qt.Key_PageUp) { list.flick(0, 2000); event.accepted = true; }
                        }
                        Label { visible: !search.text; text: root.heldText || "Search: what it does, or keys (super q)"; role: "dim"; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }

        // The essentials across the card, then the sections, in columns.
        Flickable {
            id: list
            x: Tokens.padding * 1.5
            y: header.y + header.height + Tokens.gap * 2
            width: card.width - 2 * x
            height: card.height - y - Tokens.padding * 1.5
            contentWidth: width
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: content
                width: list.width
                spacing: Tokens.gap * 2
                Column {
                    visible: !!root.essentials
                    spacing: Tokens.gap * 0.4
                    SectionTitle { text: "ESSENTIALS" }
                    Grid {
                        columns: card.cols
                        columnSpacing: Tokens.gap * 2
                        rowSpacing: Tokens.gap * 0.4
                        Repeater {
                            model: root.essentials ? root.essentials.rows : []
                            delegate: BindRow { required property var modelData; bind: modelData }
                        }
                    }
                }
                Row {
                    spacing: Tokens.gap * 2
                    Repeater {
                        model: root.columns
                        delegate: Column {
                            id: column
                            required property var modelData
                            width: card.colW
                            spacing: Tokens.gap * 2
                            Repeater {
                                model: column.modelData
                                delegate: Column {
                                    id: section
                                    required property var modelData
                                    spacing: Tokens.gap * 0.4
                                    SectionTitle { text: section.modelData.section.toUpperCase() }
                                    Repeater {
                                        model: section.modelData.rows
                                        delegate: BindRow { required property var modelData; bind: modelData }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        // There is more below.
        Rectangle {
            anchors { left: list.left; right: list.right; bottom: list.bottom }
            height: Tokens.islandHeight * 1.4
            visible: list.contentY + list.height < list.contentHeight - 1
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Colors.alpha(Colors.surface, 0.92) }
            }
        }
        Label {
            anchors.centerIn: list
            visible: root.sections.length === 0
            text: !root.binds.length ? "No binds.json yet — run ./install.sh --only session"
                : root.heldText ? "No keybind uses just " + root.heldText : "No keybind matches “" + root.query + "”"
            role: "dim"
        }
    }
}
