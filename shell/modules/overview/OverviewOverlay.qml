import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components
import "../../lib/overview.js" as Lib

/*
 * Over niri's overview: a rail of this output's workspaces on the left (index,
 * name, window count; click to go there) and, on the focused output, a filter
 * field — type to find a window by title or app, Enter to go to it.
 *
 * The overlay holds the keyboard while the overview is open, so typing goes to
 * the field; with the field empty the arrows still move around the overview,
 * and Escape closes it. Only the rail and the field take the mouse — the rest
 * of the overview stays niri's.
 */
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property bool open: Niri.overviewOpen && Settings.get("overview.overlay", true)
    readonly property bool focused_: screen.name === (Niri.focusedOutput || Quickshell.screens[0].name)

    visible: true
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "vitrum-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open && focused_ ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region {
        item: root.open ? railBox : dot
        Region { item: root.open && root.focused_ ? search : dot }
    }
    BlurKick { id: blurKick; window: root }
    BackgroundEffect.blurRegion: Materials.wantsRegion("overlay") && !blurKick.on ? effect : blurKick.none
    Region {
        id: effect
        item: root.open ? railBox : dot; radius: root.open ? railBox.radius : 0
        Region { item: root.open && root.focused_ ? search : dot; radius: root.open && root.focused_ ? search.radius : 0 }
    }
    Item { id: dot; width: 1; height: 1 }

    readonly property var names: {
        const m = {};
        for (const w of Niri.windowList) { const a = Apps.forAppId(w.appId); if (a) m[w.appId] = a.name; }
        return m;
    }
    property string query: ""
    property int current: 0
    readonly property var matches: query.trim() ? Lib.filter(Niri.windowsByRecency(), query, names).slice(0, 8) : []
    onOpenChanged: { query = ""; input.text = ""; current = 0; if (open && focused_) input.forceActiveFocus(); }
    // The keyboard follows the focused output; so must the field's focus.
    onFocused_Changed: if (open && focused_) input.forceActiveFocus()
    onQueryChanged: current = 0
    Connections { target: UiState; function onOverviewQueryRequested(t) { if (root.open && root.focused_) input.text = t; } }

    function go(w) {
        if (!w) return;
        Niri.focusWindow(w.id);
        Niri.action("close-overview");
    }

    // ------------------------------------------------------------ rail ---
    Surface {
        id: railBox
        group: "overlay"
        x: Tokens.gap * 2
        anchors.verticalCenter: parent.verticalCenter
        width: railCol.implicitWidth + 2 * Tokens.padding * 0.75
        height: railCol.implicitHeight + 2 * Tokens.padding * 0.75
        radius: Tokens.radiusPanel
        opacity: root.open ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
        transform: Translate { x: root.open ? 0 : -24; Behavior on x { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } } }
        Column {
            id: railCol
            anchors.centerIn: parent
            spacing: Tokens.gap / 2
            Repeater {
                model: Lib.rail(Niri.workspacesOn(root.screen.name), Niri.windowList)
                delegate: Rectangle {
                    required property var modelData
                    width: Math.max(Tokens.islandHeight * 3.2, rowContent.implicitWidth + Tokens.padding * 1.5)
                    height: Tokens.islandHeight * 1.2
                    radius: height / 2
                    color: modelData.active ? Colors.accent : wsMouse.containsMouse ? Colors.alpha(Colors.text, 0.1) : "transparent"
                    Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
                    Row {
                        id: rowContent
                        anchors.centerIn: parent
                        spacing: Tokens.gap
                        Label { text: modelData.label; numeric: true; font.weight: Font.DemiBold; role: modelData.active ? "onAccent" : "text"; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: modelData.count ? modelData.count + (modelData.count === 1 ? " window" : " windows") : "empty"
                                size: Tokens.textSmall; role: modelData.active ? "onAccent" : "dim"; opacity: 0.85; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: wsMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Niri.focusWorkspace(modelData.idx) }
                }
            }
        }
    }

    // ---------------------------------------------------------- search ---
    Surface {
        id: search
        group: "overlay"
        visible: opacity > 0 && root.focused_
        opacity: root.open ? 1 : 0
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
        width: Tokens.islandHeight * 16
        height: searchCol.implicitHeight + 2 * Tokens.padding * 0.75
        radius: root.matches.length ? Tokens.radiusPanel : height / 2
        Behavior on height { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
        anchors.horizontalCenter: parent.horizontalCenter
        y: Tokens.islandHeight + Tokens.gap * 3
        clip: true
        Column {
            id: searchCol
            x: Tokens.padding; y: Tokens.padding * 0.75
            width: parent.width - 2 * Tokens.padding
            spacing: Tokens.gap / 2
            Row {
                width: parent.width; height: Tokens.islandHeight
                spacing: Tokens.gap
                Icon { name: "search"; color: Colors.textDim; anchors.verticalCenter: parent.verticalCenter }
                TextInput {
                    id: input
                    width: parent.width - Tokens.iconSize - Tokens.gap
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Tokens.fontText; font.pixelSize: Tokens.textLarge
                    color: Colors.text; selectionColor: Colors.accent
                    clip: true
                    onTextChanged: root.query = text
                    Label { visible: input.text.length === 0; text: "Find a window"; role: "dim"; size: Tokens.textLarge; anchors.verticalCenter: parent.verticalCenter }
                    Keys.onPressed: e => {
                        const k = e.key, searching = root.matches.length > 0;
                        if (k === Qt.Key_Escape) { if (input.text) input.text = ""; else Niri.action("close-overview"); }
                        else if (k === Qt.Key_Return || k === Qt.Key_Enter) { if (searching) root.go(root.matches[root.current]); else Niri.action("close-overview"); }
                        else if (searching && k === Qt.Key_Down) root.current = Math.min(root.matches.length - 1, root.current + 1);
                        else if (searching && k === Qt.Key_Up) root.current = Math.max(0, root.current - 1);
                        // Nothing typed: the arrows are the overview's.
                        else if (!input.text && k === Qt.Key_Left) Niri.action("focus-column-left");
                        else if (!input.text && k === Qt.Key_Right) Niri.action("focus-column-right");
                        else if (!input.text && k === Qt.Key_Up) Niri.action("focus-workspace-up");
                        else if (!input.text && k === Qt.Key_Down) Niri.action("focus-workspace-down");
                        else return;
                        e.accepted = true;
                    }
                }
            }
            Repeater {
                model: root.matches
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property var app: Apps.forAppId(modelData.appId)
                    readonly property var ws: Niri.workspaces[modelData.workspaceId]
                    width: searchCol.width; height: Tokens.islandHeight * 1.3
                    radius: Tokens.radiusInner
                    color: index === root.current ? Colors.alpha(Colors.accent, 0.22) : hitMouse.containsMouse ? Colors.alpha(Colors.text, 0.06) : "transparent"
                    Row {
                        anchors.fill: parent; anchors.leftMargin: Tokens.gap; anchors.rightMargin: Tokens.gap
                        spacing: Tokens.gap
                        IconImage { implicitSize: Tokens.iconSize * 1.3; anchors.verticalCenter: parent.verticalCenter
                                    source: Quickshell.iconPath(app ? app.icon : modelData.appId, "application-x-executable") }
                        Label { width: parent.width - Tokens.iconSize * 1.3 - where.implicitWidth - 2 * Tokens.gap; text: modelData.title || modelData.appId
                                anchors.verticalCenter: parent.verticalCenter; font.weight: index === root.current ? Font.DemiBold : Font.Normal }
                        Label { id: where; text: (app ? app.name : modelData.appId) + (ws ? " · " + ws.idx : ""); role: "dim"; size: Tokens.textSmall; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: hitMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.go(modelData) }
                }
            }
        }
    }
}
