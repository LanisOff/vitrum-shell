import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components
import "../../lib/screencast.js" as Lib

/*
 * What to share when an app asks (Discord, a browser, OBS): screens with a
 * live preview, or windows. vitrum-portal asks for it through
 * `vitrum-ipc screencast pick <request> <types> <multiple> <app>` and waits
 * for the answer in $XDG_RUNTIME_DIR/vitrum-screencast/<request>.json.
 */
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property var req: UiState.screencastRequest
    readonly property bool open: req !== null && !!modelData && modelData.name === (Niri.focusedOutput || Quickshell.screens[0].name)

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

    // ------------------------------------------------------------ state ---
    readonly property bool canScreens: !!req && (req.types & 1)
    readonly property bool canWindows: !!req && (req.types & 2)
    property string tab: "screens"
    property int current: 0
    property bool cursor: true
    /// Apps that take several sources (OBS): the tiles ticked, by index.
    property var picked: []
    /// "Always share this with <app>": answered from memory next time.
    property bool rememberIt: false
    readonly property bool multi: !!req && req.multiple
    // Live screen previews; VITRUM_NO_SCREENCOPY=1 turns them off (nested tests).
    readonly property bool livePreviews: Quickshell.env("VITRUM_NO_SCREENCOPY") !== "1"
    readonly property var screenItems: Quickshell.screens.map(s => ({ kind: "monitor", screen: s, name: s.name }))
    readonly property var windowItems: Niri.windowsByRecency().map(w => ({ kind: "window", win: w }))
    readonly property var items: tab === "screens" ? screenItems : windowItems

    // Window pictures: one frame of a cast per window (tools/vitrum-thumbs),
    // shown as they arrive; until then, and where none comes, the app's icon.
    property string thumbDir: ""
    property int thumbGen: 0
    function loadThumbs() {
        const ids = windowItems.map(w => String(w.win.id));
        if (!ids.length || thumbProc.running) return;
        thumbDir = ScreenShare.dir + "/thumbs-" + Date.now();
        thumbProc.command = ["sh", "-c", 'rm -rf "$1"/thumbs-*; shift; exec vitrum-thumbs "$@"', "_", ScreenShare.dir, thumbDir].concat(ids);
        thumbProc.running = true;
    }
    Process { id: thumbProc; onExited: root.thumbGen++ }
    Timer { interval: 400; repeat: true; running: thumbProc.running; onTriggered: root.thumbGen++ }

    onOpenChanged: if (open) {
        if (req.types & 2) loadThumbs();
        // From req itself: canScreens may not have caught up when open flips.
        tab = (req.types & 1) ? "screens" : "windows";
        current = 0;
        cursor = true;
        picked = [];
        rememberIt = false;
        keys.forceActiveFocus();
    }

    function share() {
        const chosen = multi && picked.length ? picked.map(i => items[i]).filter(x => x) : [items[current]].filter(x => x);
        if (!chosen.length) return;
        ScreenShare.answer({ ok: true, cursor: cursor, sources: Lib.sourcesOf(chosen) },
                           rememberIt && chosen.length === 1 ? Lib.entryFor(chosen[0], cursor) : null);
    }
    function cancel() { ScreenShare.answer({ ok: false }, null); }
    /// A tile's click: ticks it (several sources), or picks it.
    function choose(i) {
        if (!multi) { current = i; return; }
        current = i;
        const p = picked.slice(), at = p.indexOf(i);
        if (at >= 0) p.splice(at, 1); else p.push(i);
        picked = p;
    }
    Connections { target: UiState; function onScreencastShareRequested(index) { if (root.open) { root.current = index; root.share(); } } }
    function appName() { return ScreenShare.appName(req ? req.app : ""); }

    // ---------------------------------------------------------- surface ---
    Rectangle {
        anchors.fill: parent
        color: Colors.alpha("#000000", root.open ? 0.4 : 0)
        Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.standard } }
    }
    MouseArea { id: catcher; anchors.fill: parent; onClicked: root.cancel() }

    Surface {
        id: card
        group: "overlay"
        readonly property real tileW: Tokens.islandHeight * 8
        readonly property int cols: Math.max(2, Math.min(3, root.items.length, Math.floor((root.width * 0.8) / (tileW + Tokens.gap * 1.5))))
        width: cols * tileW + (cols - 1) * Tokens.gap * 1.5 + 2 * Tokens.padding * 1.5
        height: Math.min(root.height * 0.82, body.implicitHeight + 2 * Tokens.padding * 1.5)
        anchors.centerIn: parent
        radius: Tokens.radiusPanel
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.96
        visible: opacity > 0
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
        Behavior on scale { enabled: Motion.enabled; NumberAnimation { duration: Motion.standard; easing.type: Easing.OutQuint } }
        Behavior on height { enabled: Motion.enabled && root.open; NumberAnimation { duration: Motion.standard; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }

        Item {
            id: keys
            focus: root.open
            Keys.onEscapePressed: root.cancel()
            Keys.onReturnPressed: root.share()
            Keys.onEnterPressed: root.share()
            Keys.onPressed: event => {
                const n = root.items.length;
                if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) { root.current = Math.min(n - 1, root.current + (event.key === Qt.Key_Down ? card.cols : 1)); event.accepted = true; }
                else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) { root.current = Math.max(0, root.current - (event.key === Qt.Key_Up ? card.cols : 1)); event.accepted = true; }
                else if (event.key === Qt.Key_Tab && root.canScreens && root.canWindows) { root.tab = root.tab === "screens" ? "windows" : "screens"; root.current = 0; root.picked = []; event.accepted = true; }
                else if (event.key === Qt.Key_Space && root.multi) { root.choose(root.current); event.accepted = true; }
            }
        }

        Column {
            id: body
            x: Tokens.padding * 1.5; y: Tokens.padding * 1.5
            width: card.width - 2 * x
            spacing: Tokens.gap * 1.5

            // Who is asking.
            Row {
                spacing: Tokens.gap
                Rectangle {
                    width: Tokens.islandHeight * 1.3; height: width; radius: width / 2
                    color: Colors.alpha(Colors.accent, 0.2)
                    Icon { anchors.centerIn: parent; name: "screen"; color: Colors.accent }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Label { text: "Share your screen"; size: Tokens.textLarge; font.weight: Font.DemiBold }
                    Label { text: root.appName() + " wants to see " + (root.canWindows && !root.canScreens ? "a window" : root.canScreens && !root.canWindows ? "a screen" : "a screen or a window"); role: "dim" }
                }
            }

            // Screens | Windows
            Row {
                visible: root.canScreens && root.canWindows
                spacing: Tokens.gap * 0.5
                Repeater {
                    model: [{ id: "screens", label: "Screens", icon: "screen" }, { id: "windows", label: "Windows", icon: "window" }]
                    delegate: Capsule {
                        required property var modelData
                        icon: modelData.icon; label: modelData.label
                        active: root.tab === modelData.id
                        onClicked: { root.tab = modelData.id; root.current = 0; root.picked = []; }
                    }
                }
            }

            Flickable {
                id: list
                width: parent.width
                height: Math.min(grid.implicitHeight, root.height * 0.82 - Tokens.islandHeight * 6)
                contentHeight: grid.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Grid {
                    id: grid
                    columns: card.cols
                    spacing: Tokens.gap * 1.5
                    Repeater {
                        model: root.items
                        delegate: Item {
                            id: tile
                            required property var modelData
                            required property int index
                            readonly property bool on: root.multi ? root.picked.indexOf(index) >= 0 : index === root.current
                            width: card.tileW
                            height: preview.height + caption.height + Tokens.gap
                            scale: tileMouse.pressed ? 0.97 : 1
                            Behavior on scale { enabled: Motion.enabled; NumberAnimation { duration: Motion.fast } }

                            Rectangle {
                                id: preview
                                width: parent.width
                                height: width * 9 / 16
                                radius: Tokens.radiusInner * 1.5
                                color: Colors.alpha(Colors.text, 0.06)
                                clip: true
                                border.width: tile.on || (root.multi && tile.index === root.current) ? 2 : 1
                                border.color: tile.on ? Colors.accent : root.multi && tile.index === root.current ? Colors.alpha(Colors.accent, 0.5) : Colors.alpha(Colors.text, 0.12)
                                Behavior on border.color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
                                // A screen: live. A window: its app (niri has no window previews).
                                // Created only while the picker is open: screencopy binds the
                                // compositor's dmabuf interface, and a compositor offering an
                                // old version (nested niri) drops the whole shell otherwise.
                                Loader {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    active: tile.modelData.kind === "monitor" && root.open && root.livePreviews
                                    sourceComponent: ScreencopyView {
                                        visible: hasContent
                                        captureSource: tile.modelData.screen
                                        live: true
                                        paintCursor: false
                                    }
                                }
                                Icon {
                                    visible: tile.modelData.kind === "monitor" && !root.livePreviews
                                    anchors.centerIn: parent
                                    name: "screen"; size: parent.height * 0.35; color: Colors.textDim
                                }
                                Image {
                                    id: thumb
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    visible: tile.modelData.kind === "window" && status === Image.Ready
                                    source: tile.modelData.kind === "window" && root.thumbDir
                                        ? "file://" + root.thumbDir + "/" + tile.modelData.win.id + ".ppm?" + root.thumbGen : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: false
                                }
                                IconImage {
                                    visible: tile.modelData.kind === "window" && thumb.status !== Image.Ready
                                    anchors.centerIn: parent
                                    implicitSize: parent.height * 0.42
                                    source: tile.modelData.kind === "window"
                                        ? Quickshell.iconPath((Apps.forAppId(tile.modelData.win.appId) || {}).icon || tile.modelData.win.appId, "application-x-executable") : ""
                                }
                                Rectangle {
                                    visible: tile.on
                                    anchors { right: parent.right; top: parent.top; margins: Tokens.gap * 0.6 }
                                    width: Tokens.iconSize * 1.3; height: width; radius: width / 2
                                    color: Colors.accent
                                    Icon { anchors.centerIn: parent; name: "check"; color: Colors.onAccent; size: Tokens.iconSize * 0.8 }
                                }
                            }
                            Column {
                                id: caption
                                anchors { top: preview.bottom; topMargin: Tokens.gap * 0.6 }
                                width: parent.width
                                Label {
                                    width: parent.width; elide: Text.ElideRight; font.weight: Font.DemiBold
                                    text: tile.modelData.kind === "monitor" ? tile.modelData.name : (tile.modelData.win.title || tile.modelData.win.appId)
                                }
                                Label {
                                    width: parent.width; elide: Text.ElideRight; role: "dim"; size: Tokens.textSmall
                                    text: tile.modelData.kind === "monitor"
                                        ? tile.modelData.screen.width + " × " + tile.modelData.screen.height
                                        : (Apps.forAppId(tile.modelData.win.appId) || {}).name || tile.modelData.win.appId
                                }
                            }
                            MouseArea {
                                id: tileMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.choose(tile.index)
                                onDoubleClicked: if (!root.multi) { root.current = tile.index; root.share(); }
                            }
                        }
                    }
                }
            }
            Label { visible: root.items.length === 0; text: root.tab === "windows" ? "No windows open" : "No screens"; role: "dim" }

            // Cursor, cancel, share.
            Item {
                width: parent.width
                height: Tokens.islandHeight * 2.4
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.gap / 2
                    Row {
                        spacing: Tokens.gap
                        Toggle { checked: root.cursor; onToggled: root.cursor = !root.cursor; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: "Show the pointer"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    // Next time this app asks, share the same without asking.
                    Row {
                        visible: !!root.req && !!root.req.app && !(root.multi && root.picked.length > 1)
                        spacing: Tokens.gap
                        Toggle { checked: root.rememberIt; onToggled: root.rememberIt = !root.rememberIt; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: "Always share this with " + root.appName(); anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: Tokens.gap
                    Capsule { label: "Cancel"; onClicked: root.cancel() }
                    Capsule { icon: "screen"; label: root.multi && root.picked.length > 1 ? "Share " + root.picked.length : "Share"; active: true; onClicked: root.share() }
                }
            }
        }
    }
}
