import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.components
import "../../lib/bar.js" as BarLib
import "../../lib/drop.js" as Drop

/*
 * The bar of one screen, and the panels that flow out of it.
 *
 * One full-screen, transparent layer surface holds the islands, the activity
 * islands (a timer, a recording: there only while it runs) and the open panel;
 * BarReserve, a second, empty surface, reserves the space. Only the islands
 * and an open panel take input (mask).
 *
 * With glass on the bar and a niri that has shaped glass (Materials.shaped),
 * the effect region is plain rectangles and niri rounds them: every island is
 * its own lens, and an open panel hangs from its island on a short neck,
 * melted into one drop by niri's fillets (lib/drop.js has the geometry).
 * Without it every piece is its own rounded region, as before.
 *
 *   panels: { name: Component }   what each UiState.panel name shows
 */
PanelWindow {
    id: bar
    required property var modelData
    property var panels: ({})
    screen: modelData

    readonly property bool atTop: Settings.get("bar.position", "top") === "top"
    readonly property string primaryName: BarLib.primaryScreen(Quickshell.screens, Settings.get("bar.primary", ""))
    readonly property bool primary: screen && screen.name === primaryName
    readonly property var layout: BarLib.parseLayout(Settings.get("bar.layout", {})).layout
    readonly property real span: Tokens.islandHeight + 2 * Tokens.gap
    readonly property bool shaped: Materials.shaped("bar")
    // What niri rounds every piece with in shaped mode (vitrum-theme writes the same).
    readonly property real pieceRadius: Tokens.islandRadius
    readonly property real fillet: Tokens.islandRadius

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "vitrum-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // ------------------------------------------------------------ islands ---
    // Every island registers itself; regions follow.
    property var islands: []
    function _collect() {
        const out = [];
        for (const row of [left, center, activities, right])
            for (let i = 0; i < row.children.length; i++) {
                const c = row.children[i];
                if (c.region && c.visible) out.push(c);
            }
        islands = out;
    }
    readonly property var islandRegions: islands.map(i => i.region)

    component Side: Row {
        property var islandList: []
        z: 2                       // above the click catcher: another island's click switches panels
        spacing: Tokens.gap
        y: bar.atTop ? Tokens.gap : bar.height - Tokens.gap - Tokens.islandHeight
        height: Tokens.islandHeight
        Repeater {
            model: parent.islandList
            delegate: IslandView {
                required property var modelData
                modules: modelData
                screen: bar.screen
                primary: bar.primary
                shaped: bar.shaped
                merged: bar.shaped && bar.source === this && bar.t > 0.02
                onRegionChanged: bar._collect()
                onVisibleChanged: Qt.callLater(bar._collect)
                Component.onCompleted: bar._collect()
                Component.onDestruction: Qt.callLater(bar._collect)
            }
        }
    }

    Side { id: left;   islandList: bar.layout.left;   x: Tokens.gap }
    Side { id: center; islandList: bar.layout.center; x: Math.round((bar.width - width) / 2) }
    // Activities sit right of the centre, each an island of its own that is
    // only there while its activity runs.
    Side { id: activities; islandList: bar.layout.activities; x: center.x + center.width + (center.width > 0 ? Tokens.gap : 0) }
    Side { id: right;  islandList: bar.layout.right;  x: bar.width - width - Tokens.gap }

    // -------------------------------------------------------------- panel ---
    readonly property bool mine: UiState.panel !== "" && UiState.panelScreen === modelData
    property bool open: false
    property bool closing: false
    property string shown: ""
    property Item source: null
    property rect anchorRect: Qt.rect(0, 0, 0, 0)

    // The island a panel flows out of: the one that asked, else (IPC) the first
    // island with a module that opens it.
    function _findSource(name) {
        const s = UiState.panelSource;
        for (const i of islands) if (i === s) return i;
        for (const i of islands) if (i.opens(name)) return i;
        return null;
    }
    // Set while a panel's content is being swapped in: its first size is taken
    // as is (the drop grows into it); later changes ease.
    property bool taking: false
    function _take() {
        taking = true;
        Qt.callLater(() => bar.taking = false);
        shown = UiState.panel;
        source = _findSource(UiState.panel);
        anchorRect = UiState.panelAnchor;
    }
    Timer { id: closeTimer; interval: Math.max(1, Motion.standard + 60); onTriggered: bar.closing = false }
    onMineChanged: {
        if (mine) { closeTimer.stop(); closing = false; _take(); open = true; }
        else if (open) { open = false; closing = true; closeTimer.restart(); }
    }
    Connections {
        target: UiState
        function onPanelChanged() { if (bar.mine && UiState.panel !== bar.shown) bar._take(); }
    }

    // One progress value drives the whole drop: island (0) to panel (1). Opening
    // overshoots a touch — the drop swells and settles.
    property real t: open ? 1 : 0
    Behavior on t {
        enabled: Motion.enabled
        NumberAnimation {
            duration: bar.open ? Math.round(Motion.emphasized * 1.25) : Motion.standard
            easing.type: bar.open ? Easing.OutBack : Easing.InOutCubic
            easing.overshoot: 1.05
        }
    }
    readonly property bool dropShown: t > 0.001 && (open || closing)

    // The island in the bar's frame (y from the bar's edge), followed live: it
    // springs when its contents change, and the drop goes with it. Switching to
    // another island's panel slides the neck along the bar.
    readonly property real srcX: source ? source.parent.x + source.x : anchorRect.x
    readonly property real srcW: source ? source.width : Math.max(anchorRect.width, 1)
    // The island already springs when its contents change, so the drop follows
    // it exactly; only a move to another island's panel animates. (Easing both
    // edges on their own while the island grew let them part: the panel swung
    // aside and back when the centre island widened under an open calendar.)
    property real ix: srcX
    property real iw: srcW
    property bool sliding: false
    onSourceChanged: if (t > 0.99) { sliding = true; slideEnd.restart(); }
    Timer { id: slideEnd; interval: Motion.standard + 30; onTriggered: bar.sliding = false }
    Behavior on ix { enabled: Motion.enabled && bar.sliding; NumberAnimation { duration: Motion.standard; easing.type: Easing.OutCubic } }
    Behavior on iw { enabled: Motion.enabled && bar.sliding; NumberAnimation { duration: Motion.standard; easing.type: Easing.OutCubic } }

    // The panel's size comes from its content; centred under the island, on screen.
    readonly property real tw: loader.item ? loader.item.width + 2 * Tokens.padding : 0
    readonly property real th: loader.item ? loader.item.implicitHeight + 2 * Tokens.padding : 0
    readonly property real tx: Math.max(Tokens.gap, Math.min(width - tw - Tokens.gap, ix + iw / 2 - tw / 2))
    property real aw: tw
    property real ah: th
    // Eased also while the drop is still opening: content that settles its
    // size a moment after it loads (the player: its cover, its lyrics) jerked
    // the half-open drop.
    readonly property bool easeSize: Motion.enabled && (t > 0.99 || (open && !taking))
    Behavior on aw { enabled: bar.easeSize; NumberAnimation { duration: Motion.standard; easing.type: Easing.OutCubic } }
    Behavior on ah { enabled: bar.easeSize; NumberAnimation { duration: Motion.standard; easing.type: Easing.OutCubic } }

    readonly property var islandFrame: ({ x: ix, y: Tokens.gap, w: iw, h: Tokens.islandHeight })
    readonly property var geo: Drop.dropGeometry(islandFrame, { x: tx, w: aw, h: ah }, t, Tokens.gap)
    readonly property var neckRect: Drop.mirrorRect(geo.neck, !atTop, height)
    readonly property var sheetRect: Drop.mirrorRect(geo.sheet, !atTop, height)

    // The tint along the drop's outline (shaped glass), under everything else.
    Shape {
        anchors.fill: parent
        z: -1
        visible: bar.shaped && bar.dropShown
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: Materials.fill("bar", 0)
            PathSvg { path: bar.shaped && bar.dropShown ? Drop.dropPath(bar.islandFrame, bar.geo.sheet, bar.pieceRadius, bar.fillet, !bar.atTop, bar.height) : "" }
        }
    }

    Item { id: neck; x: bar.neckRect.x; y: bar.neckRect.y; width: bar.neckRect.w; height: bar.neckRect.h }

    MouseArea { id: catcher; anchors.fill: parent; enabled: bar.open; onClicked: UiState.closePanel() }

    Item {
        id: sheet
        z: 1
        x: bar.sheetRect.x; y: bar.sheetRect.y
        width: bar.sheetRect.w; height: bar.sheetRect.h
        visible: bar.dropShown
        clip: true

        // Without shaped glass the sheet is its own rounded surface.
        Surface {
            anchors.fill: parent
            visible: !bar.shaped
            group: "bar"
            radius: Math.min(Tokens.radiusPanel, width / 2, height / 2)
        }
        MouseArea { anchors.fill: parent }   // clicks inside do not close

        Loader {
            id: loader
            x: Tokens.padding
            // Pinned to the far edge of the sheet from the bar: content slides
            // out of the island rather than being uncovered top-down.
            y: bar.atTop ? sheet.height - bar.ah + Tokens.padding : Tokens.padding
            sourceComponent: bar.panels[bar.shown] || null
            opacity: bar.open && bar.t > 0.55 ? 1 : 0
            Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
        }
    }

    // ------------------------------------------------- regions and input ---
    Item { id: dotItem; width: 1; height: 1 }
    Region { id: dotRegion; item: dotItem }
    Region { id: neckRegion; item: neck }
    Region { id: sheetRegion; item: sheet; radius: bar.shaped ? 0 : Math.min(Tokens.radiusPanel, sheet.width / 2, sheet.height / 2) }
    Region { id: catcherRegion; item: catcher }

    readonly property var dropRegions: !dropShown ? [] : shaped ? [neckRegion, sheetRegion] : [sheetRegion]
    // Never an empty region: niri would apply the effect to the whole surface.
    Region {
        id: effectRegion
        regions: {
            const r = bar.islandRegions.concat(bar.dropRegions);
            return r.length ? r : [dotRegion];
        }
    }
    BlurKick { id: blurKick; window: bar }
    BackgroundEffect.blurRegion: Materials.wantsRegion("bar") && !blurKick.on ? effectRegion : blurKick.none

    mask: Region {
        regions: bar.open ? bar.islandRegions.concat([catcherRegion]) : bar.closing ? bar.islandRegions.concat([sheetRegion]) : bar.islandRegions
    }

    Item {
        focus: bar.open
        Keys.onEscapePressed: UiState.closePanel()
    }

    Connections {
        target: UiState
        function onBarProbe() {
            const d = Object.assign({}, UiState.barDebug);
            d[bar.modelData.name] = { open: bar.open, closing: bar.closing, shown: bar.shown, t: bar.t, shaped: bar.shaped,
                                      source: !!bar.source, geo: bar.geo, islands: bar.islands.length, w: bar.width, h: bar.height };
            UiState.barDebug = d;
        }
    }

    // Stay awake (Awake): one inhibitor, held by the primary bar.
    IdleInhibitor { window: bar; enabled: bar.primary && Awake.active }
}
