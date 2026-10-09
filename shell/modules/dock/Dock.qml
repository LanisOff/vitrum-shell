import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components
import "../../lib/dock.js" as DockLib

/*
 * The dock: one, on the focused screen, at the bottom.
 *
 * Intellihide (dock.intellihide): it hides only when a window actually
 * reaches into its rectangle — computed from niri's tile positions, no
 * polling — and comes back on hover over a thin strip at the edge.
 *
 * Click: focus the app's most recent window, or launch it. Middle click: a
 * new window. Right click: a menu above the icon — new window, close, keep in
 * / remove from the Dock. It goes on Escape, on a choice, or when the pointer
 * has left the dock for a moment.
 */
PanelWindow {
    id: root
    property var targetScreen: null
    screen: targetScreen
    /// This screen's dock is the one in use (the focused screen).
    property bool active: true
    onActiveChanged: if (active) UiState.activeDock = root

    readonly property bool enabled_: Settings.get("dock.enabled", true)
    readonly property int icon: Settings.get("dock.iconSize", 44)
    readonly property bool magnify: Settings.get("dock.magnify", true)
    // Magnification: the icon under the pointer grows to `magnifyAmount`, its
    // neighbours less, on a bell curve of their distance from the pointer. The
    // slots widen (not just scale), so the row spreads instead of overlapping.
    readonly property real magnifyAmount: Math.max(1, Settings.get("dock.magnifyAmount", 1.4))
    readonly property bool zooming: magnify && hover.hovered && !menuOpen
    // How much of the magnification is on: eases in when the pointer arrives and
    // out when it leaves, so the row never jumps. While the pointer moves the
    // curve follows it directly — a spring there trails behind the hand.
    property real lift: zooming ? 1 : 0
    Behavior on lift { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }
    // The pointer in the unmagnified row's coordinates, from the window (which
    // never moves), not from the row: the row widens under the pointer, and a
    // position measured in it lags a frame and makes the icons shake. Kept after
    // the pointer leaves, so the icons settle back where they were. Held to the
    // row's ends: past them the end icons would shrink, the plate would narrow
    // under the pointer and drop it — a sideways exit snapped shut. And a leave
    // resets the handler's point to 0,0 (off the plate), which is ignored.
    readonly property real baseRowW: model.length * icon + Math.max(0, model.length - 1) * Tokens.gap
    property real pointerX: -1
    readonly property real hoverX: hover.point.position.x
    onHoverXChanged: {
        if (!hover.hovered || hoverX < plate.x || hoverX > plate.x + plate.width) return;
        pointerX = Math.max(0, Math.min(baseRowW, hoverX - (width - baseRowW) / 2));
    }
    function zoomAt(index) {
        if (lift <= 0.001 || pointerX < 0) return 1;
        const d = pointerX - (index * (icon + Tokens.gap) + icon / 2), sigma = icon * 0.95;
        return 1 + (magnifyAmount - 1) * lift * Math.exp(-d * d / (2 * sigma * sigma));
    }
    readonly property var model: DockLib.items(Settings.get("dock.pinned", []), Niri.windowList)

    // Where the plate sits in output coordinates, for the overlap test.
    readonly property real plateW: row.implicitWidth + 2 * Tokens.padding
    readonly property real plateH: icon + 2 * Tokens.padding
    readonly property real barTop: Settings.get("bar.position", "top") === "top" ? Tokens.islandHeight + 2 * Tokens.gap : 0
    // From targetScreen, not the window's own screen/width: those change as the dock maps and unmaps.
    readonly property var ts: targetScreen
    readonly property rect plateRect: Qt.rect(((ts ? ts.width : 0) - plateW) / 2, (ts ? ts.height : 0) - Tokens.gap - plateH, plateW, plateH)
    readonly property bool overlapping: ts ? DockLib.overlaps({ x: plateRect.x, y: plateRect.y, w: plateRect.width, h: plateRect.height },
                                                              Niri.tilesOn(ts.name, barTop)) : false
    property bool hovered: false
    readonly property bool shown: enabled_ && active && (!Settings.get("dock.intellihide", true)
        || DockLib.intellihideVisible({ hovered: hovered || menuOpen, overlapping: overlapping, dragging: false, settingsMode: UiState.widgetsEdit }))

    // The right-click menu: which app it is for, and where its icon's centre is.
    property string menuApp: ""
    property real menuX: 0
    readonly property bool menuOpen: menuApp !== ""
    readonly property var menuItem: menuOpen ? model.find(m => m.appId.toLowerCase() === menuApp.toLowerCase()) || null : null
    onMenuItemChanged: if (menuOpen && !menuItem) menuApp = ""   // unpinned and closed: nothing left to act on

    // Mapped only while shown or sliding away. A hidden dock that stayed mapped
    // was blurred whole by niri on some outputs — a frosted band over every
    // window's bottom. While it is unmapped, DockEdge (no effect rule) is what
    // brings it back. Never from geometry: see components/MapGate.qml.
    MapGate { id: gate; want: root.enabled_ && root.targetScreen !== null && root.shown }
    visible: gate.mapped
    property bool edgeHovered: false
    onEdgeHoveredChanged: hideDelay.restart()
    onShownChanged: {
        if (active) UiState.dockState = shown ? "visible" : "hidden";
        if (!shown) menuApp = "";
    }
    function debugState() { return JSON.stringify({ shown: shown, overlapping: overlapping, hovered: hovered, plate: plateRect, screen: screen ? screen.name + " " + screen.height : null, tiles: screen ? Niri.tilesOn(screen.name, barTop) : null }); }
    Component.onCompleted: if (active) { UiState.activeDock = root; UiState.dockState = shown ? "visible" : "hidden"; }
    anchors { bottom: true; left: true; right: true }
    // Room above the plate for the hover label (and magnification); it takes no input.
    // Or for the right-click menu, whichever is taller.
    readonly property real menuRoom: 3 * Tokens.islandHeight + 2 * Tokens.padding + 2 * Tokens.gap
    implicitHeight: plateH + Tokens.gap + Math.max(Tokens.islandHeight + 3 * Tokens.gap + (magnify ? icon * (magnifyAmount - 1) : 0), menuRoom)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "vitrum-dock"
    WlrLayershell.layer: WlrLayer.Top
    // Only while the menu is open, for Escape.
    WlrLayershell.keyboardFocus: menuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Input: the plate while shown, the reveal strip while hidden.
    mask: Region { item: root.shown ? shape : strip; regions: root.menuOpen ? [menuInput] : [] }
    Region { id: menuInput; item: menu }
    BlurKick { id: blurKick; window: root }
    BackgroundEffect.blurRegion: Materials.wantsRegion("dock") && !blurKick.on ? effect : blurKick.none
    // Never an empty region: with none, niri applies the rule to the whole surface.
    Region { id: effect; item: shape.height >= 2 ? shape : dot; radius: shape.height >= 2 ? plate.radius : 0
             regions: root.menuOpen ? [menuEffect] : [] }
    Region { id: menuEffect; item: menu; radius: menu.radius }
    Item { id: dot; width: 1; height: 1 }
    Item { id: shape; x: plate.x; y: plate.y; width: plate.width; height: Math.max(0, Math.min(plate.height, root.height - plate.y)) }
    Item { id: strip; x: plate.x; y: root.height - 4; width: plate.width; height: 4 }

    HoverHandler { id: hover; onHoveredChanged: hideDelay.restart() }
    // The menu waits a little longer than the dock for the pointer to come back.
    Timer { interval: 700; running: root.menuOpen && !hover.hovered; onTriggered: root.menuApp = "" }
    Item { focus: root.menuOpen; Keys.onEscapePressed: root.menuApp = "" }
    // Leaving is forgiven for a moment, so a pass across the edge does not flicker it.
    Timer { id: hideDelay; interval: hover.hovered || root.edgeHovered ? 0 : 400; onTriggered: root.hovered = hover.hovered || root.edgeHovered }

    Surface {
        id: plate
        group: "dock"
        width: root.plateW
        height: root.plateH
        radius: Math.min(Tokens.radiusPanel + Tokens.padding, height / 2)
        x: (parent.width - width) / 2
        y: root.shown ? root.height - Tokens.gap - height : root.height + 2
        // One curve with a known length: the window unmaps when it is over (MapGate).
        Behavior on y { enabled: Motion.enabled; NumberAnimation { duration: root.shown ? Motion.emphasized : Motion.standard; easing.type: root.shown ? Easing.OutQuint : Easing.InCubic } }
        // While magnifying the plate follows the icons exactly; its own curve would lag them.
        Behavior on width { enabled: Motion.enabled && root.lift <= 0.001; NumberAnimation { duration: Motion.standard; easing.type: Easing.OutCubic } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: Tokens.gap
            Repeater {
                model: root.model
                delegate: Item {
                    id: slot
                    required property var modelData
                    required property int index
                    readonly property var app: Apps.forAppId(modelData.appId)
                    readonly property bool running: modelData.windows.length > 0
                    readonly property real zoom: root.zoomAt(index)
                    width: root.icon * zoom; height: root.icon

                    // The press dip, apart from the magnification so its spring never slows the zoom.
                    Item {
                        anchors.fill: parent
                        scale: mouse.pressed ? 0.9 : 1
                        transformOrigin: Item.Bottom
                        Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.bouncy } }
                        // Drawn once at the largest size and scaled down: an icon re-rendered
                        // at every new size each frame is what made the zoom stutter.
                        IconImage {
                            id: img
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                            implicitSize: root.icon * root.magnifyAmount
                            mipmap: true
                            scale: slot.zoom / root.magnifyAmount
                            transformOrigin: Item.Bottom
                            source: Quickshell.iconPath(slot.app ? slot.app.icon : slot.modelData.appId, "application-x-executable")
                        }
                    }
                    // Running: a dot; focused: a wider capsule.
                    Rectangle {
                        visible: slot.running
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: 2 }
                        height: 4; radius: 2
                        width: slot.modelData.focused ? 14 : 4
                        color: slot.modelData.focused ? Colors.accent : Colors.text
                        Behavior on width { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: m => {
                            if (m.button === Qt.RightButton) {
                                const same = root.menuApp.toLowerCase() === slot.modelData.appId.toLowerCase();
                                root.menuX = slot.mapToItem(null, slot.width / 2, 0).x;
                                root.menuApp = same ? "" : slot.modelData.appId;
                                return;
                            }
                            root.menuApp = "";
                            if (m.button === Qt.LeftButton && slot.running) {
                                const recent = Niri.windowsByRecency().find(w => w.appId.toLowerCase() === slot.modelData.appId.toLowerCase());
                                if (recent) { Niri.focusWindow(recent.id); return; }
                            }
                            if (slot.app) Apps.launch(slot.app);
                        }
                    }
                    ToolTip_ { text: slot.app ? slot.app.name : slot.modelData.appId; show: mouse.containsMouse && !root.menuOpen }
                }
            }
        }
    }

    // The menu's entries for one dock item.
    function menuActions(item) {
        if (!item) return [];
        const app = Apps.forAppId(item.appId), out = [];
        if (app) out.push({ icon: "add", text: "New window", run: () => Apps.launch(app) });
        const n = item.windows.length;
        if (n > 0) out.push({ icon: "close", text: n > 1 ? "Close all windows" : "Close window",
                              run: () => item.windows.forEach(w => Niri.closeWindow(w.id)) });
        out.push({ icon: "pin", text: item.pinned ? "Remove from Dock" : "Keep in Dock", run: () => root.togglePin(item.appId) });
        return out;
    }

    Surface {
        id: menu
        group: "dock"
        visible: opacity > 0
        opacity: root.menuOpen ? 1 : 0
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
        width: Math.max(menuCol.implicitWidth + 2 * Tokens.padding, 180)
        height: menuCol.implicitHeight + 2 * Tokens.padding
        radius: Tokens.radiusPanel
        x: Math.max(Tokens.gap, Math.min(root.width - width - Tokens.gap, root.menuX - width / 2))
        y: plate.y - Tokens.gap - height

        Column {
            id: menuCol
            anchors.centerIn: parent
            width: parent.width - 2 * Tokens.padding
            Repeater {
                model: root.menuActions(root.menuItem)
                delegate: Rectangle {
                    id: entry
                    required property var modelData
                    width: menuCol.width
                    height: Tokens.islandHeight
                    radius: Tokens.radiusInner
                    color: entryMouse.containsMouse ? Colors.alpha(Colors.text, 0.08) : "transparent"
                    Row {
                        anchors { left: parent.left; leftMargin: Tokens.padding; verticalCenter: parent.verticalCenter }
                        spacing: Tokens.gap
                        Icon { name: entry.modelData.icon; size: Tokens.iconSize; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: entry.modelData.text; anchors.verticalCenter: parent.verticalCenter; rightPadding: Tokens.padding }
                    }
                    MouseArea {
                        id: entryMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { const run = entry.modelData.run; root.menuApp = ""; run(); }
                    }
                }
            }
        }
    }

    function togglePin(appId) {
        const p = Settings.get("dock.pinned", []).slice();
        const i = p.findIndex(x => x.toLowerCase() === appId.toLowerCase());
        if (i >= 0) p.splice(i, 1); else p.push(appId);
        Settings.set("dock.pinned", p);
    }

    // A small label above the hovered icon.
    component ToolTip_: Surface {
        property string text: ""
        property bool show: false
        group: "dock"; level: 1; outlined: false
        visible: opacity > 0
        opacity: show ? 1 : 0
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
        width: tip.implicitWidth + 2 * Tokens.padding
        height: Tokens.islandHeight
        radius: height / 2
        anchors.horizontalCenter: parent.horizontalCenter
        y: -height - Tokens.gap * 2
        Label { id: tip; anchors.centerIn: parent; text: parent.text }
    }
}
