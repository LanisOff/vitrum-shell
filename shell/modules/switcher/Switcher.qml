import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components

/*
 * Alt+Tab: windows in most-recently-used order, as cards — app icon, title,
 * workspace. Holding Alt keeps it open, Tab/Shift+Tab (or the keybind again)
 * moves, releasing Alt switches, Escape cancels.
 *
 * A quick tap can release Alt before this surface holds the keyboard, and
 * then the release never arrives (Qt does not report modifiers held when the
 * keyboard arrives). So after opening, if nothing else comes in (no second
 * Tab, no key) within switcher.quickTapMs, it switches — what a tap meant.
 * Any pointer movement over it tells the truth sooner: Alt up switches at
 * once, Alt down keeps it open.
 *
 * Live previews are not possible on niri 26.04 without copying every frame to
 * the clipboard; niri's overview (Mod+Tab) shows windows live.
 */
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property bool open: UiState.switcher && screen.name === (Niri.focusedOutput || Quickshell.screens[0].name)

    property var windows: []
    property int index: 0

    function step(d) {
        if (!UiState.switcher) {
            windows = Niri.windowsByRecency();
            if (windows.length === 0) return;
            index = windows.length > 1 ? 1 : 0;       // first Alt+Tab goes to the previous window
            UiState.closeAll();
            UiState.switcher = true;
            quickTap.restart();
            return;
        }
        quickTap.stop();
        if (windows.length) index = (index + d + windows.length) % windows.length;
    }
    function commit() {
        quickTap.stop();
        const w = windows[index];
        UiState.switcher = false;
        if (w) Niri.focusWindow(w.id);
    }
    Timer { id: quickTap; interval: Settings.get("switcher.quickTapMs", 1000); onTriggered: if (root.open) root.commit() }
    onOpenChanged: if (!open) quickTap.stop()
    Connections {
        target: UiState
        function onSwitcherStep(d) { if (root.screen.name === (Niri.focusedOutput || Quickshell.screens[0].name)) root.step(d); }
        function onSwitcherCommit() { if (root.open) root.commit(); }
    }

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
    Region { id: effect; item: card.visible ? shape : dot; radius: Tokens.radiusPanel * card.scale }
    Item { id: dot; width: 1; height: 1 }
    Item { id: shape; x: card.x + card.width * (1 - card.scale) / 2; y: card.y + card.height * (1 - card.scale) / 2; width: card.width * card.scale; height: card.height * card.scale }
    MouseArea {
        id: catcher
        anchors.fill: parent
        hoverEnabled: true
        onClicked: UiState.switcher = false
        onPositionChanged: m => {
            if (!root.open || !quickTap.running) return;
            if (m.modifiers & Qt.AltModifier) quickTap.stop(); else root.commit();
        }
    }

    readonly property int tile: Tokens.islandHeight * 5

    Surface {
        id: card
        group: "overlay"
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.94
        visible: opacity > 0
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
        Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
        width: Math.min(parent.width - 4 * Tokens.gap, row.implicitWidth + 2 * Tokens.padding)
        height: row.implicitHeight + 2 * Tokens.padding
        anchors.centerIn: parent
        clip: true
        Row {
            id: row
            x: Tokens.padding - Math.max(0, (root.index + 1) * (root.tile + Tokens.gap) - (card.width - 2 * Tokens.padding))
            y: Tokens.padding
            spacing: Tokens.gap
            Behavior on x { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
            Repeater {
                model: root.windows
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool selected: index === root.index
                    readonly property var app: Apps.forAppId(modelData.appId)
                    readonly property var ws: Niri.workspaces[modelData.workspaceId]
                    width: root.tile; height: root.tile * 0.9
                    radius: Tokens.radiusInner
                    color: selected ? Colors.alpha(Colors.accent, 0.22) : Colors.alpha(Colors.text, 0.04)
                    border.width: selected ? 2 : 0
                    border.color: Colors.accent
                    Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 2 * Tokens.padding
                        spacing: Tokens.gap
                        IconImage {
                            anchors.horizontalCenter: parent.horizontalCenter
                            implicitSize: root.tile * 0.36
                            source: Quickshell.iconPath(app ? app.icon : modelData.appId, "application-x-executable")
                        }
                        Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: modelData.title || modelData.appId; font.weight: selected ? Font.DemiBold : Font.Normal; maximumLineCount: 2; wrapMode: Text.WordWrap }
                        Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: (app ? app.name : modelData.appId) + (ws ? "  ·  " + ws.idx : ""); role: "dim"; size: Tokens.textSmall }
                    }
                    MouseArea { anchors.fill: parent; onClicked: { root.index = index; root.commit(); } }
                }
            }
        }
    }

    Item {
        focus: root.open
        Keys.onPressed: e => {
            quickTap.stop();
            if (e.key === Qt.Key_Tab) { root.step(1); e.accepted = true; }
            else if (e.key === Qt.Key_Backtab) { root.step(-1); e.accepted = true; }
            else if (e.key === Qt.Key_Right) { root.step(1); e.accepted = true; }
            else if (e.key === Qt.Key_Left) { root.step(-1); e.accepted = true; }
            else if (e.key === Qt.Key_Escape) { UiState.switcher = false; e.accepted = true; }
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.commit(); e.accepted = true; }
        }
        Keys.onReleased: e => {
            if (e.key === Qt.Key_Alt || e.key === Qt.Key_Meta) { root.commit(); e.accepted = true; }
        }
    }
}
