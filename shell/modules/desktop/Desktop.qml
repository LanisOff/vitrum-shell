import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.components
import "../../lib/widgets.js" as W
import "../../lib/wallpaper.js" as WallLib
import "../../lib/lock.js" as LockLib

/*
 * Desktop widgets, one surface per screen, under the windows (bottom layer,
 * above the wallpaper). Widgets come from widgets.items, kept per output name
 * (or on every screen: the same widget on each); a right-click on one opens
 * the editor on it.
 *
 * The editor (WidgetEditor; Mod+Alt+W, Settings, the launcher) is this same
 * surface risen to the overlay: an opaque backdrop hides the windows, and the
 * desktop — the wallpaper and the very same widgets — shrinks onto a stage,
 * right of the editor sheet on the focused screen, centred on the others.
 * Geometry stays in desktop coordinates; the stage is only a transform.
 *
 * On the stage: click / Shift-click / a rubber band to select; drag to move
 * the selection (lined up with the others); the corner to resize; drop past
 * the window's edge to send a widget to another screen. Delete, Ctrl+D,
 * Ctrl+Z / Ctrl+Shift+Z, Ctrl+A, the arrows (Shift: four steps), Escape to
 * cancel, Enter for done.
 */
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property bool editing: WidgetEditor.active
    readonly property bool focused_: screen.name === (Niri.focusedOutput || Quickshell.screens[0].name)
    readonly property int grid: WidgetEditor.grid
    readonly property var bounds: ({ w: width, h: height })
    readonly property int barSpace: Settings.get("bar.position", "top") === "top" ? Tokens.islandHeight + 2 * Tokens.gap : 0

    readonly property var items: W.forOutput(WidgetEditor.all, screen.name)
    readonly property var byId: { const m = {}; for (const i of items) m[i.id] = i; return m; }

    // The Repeater's model holds ids only and is patched, never replaced: a
    // settings change updates widgets in place instead of recreating them
    // (which reset the notes widget mid-typing and replayed every pop-in).
    ListModel { id: idModel }
    onItemsChanged: syncModel()
    function syncModel() {
        const cur = [];
        for (let i = 0; i < idModel.count; i++) cur.push(idModel.get(i).wid);
        const plan = W.syncPlan(cur, items.map(i => i.id));
        for (const i of plan.remove) idModel.remove(i);
        for (const id of plan.add) idModel.append({ wid: id });
    }
    Connections {
        target: UiState
        function onWidgetAddRequested(type) {
            if (!root.focused_) return;
            if (root.editing) WidgetEditor.addType(type, root.screen.name, root.barSpace);
            else Settings.set("widgets.items", W.add(WidgetEditor.stored, type, root.screen.name, root.bounds, root.grid, root.barSpace, WidgetEditor.newId, WidgetEditor.custom));
        }
    }

    // Mapped unless a game fills this screen (GameMode.output); the editor
    // maps it again (components/MapGate.qml).
    MapGate { id: gate; want: root.editing || GameMode.output !== root.screen.name }
    visible: gate.mapped
    // Mapped again by the editor: the window is a new one, the focus goes back in.
    onBackingWindowVisibleChanged: if (backingWindowVisible && editing && focused_) keys.forceActiveFocus()
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "vitrum-widgets"
    WlrLayershell.layer: editing ? WlrLayer.Overlay : WlrLayer.Bottom
    WlrLayershell.keyboardFocus: editing && focused_ ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

    // Input and blur follow the widgets: one rounded region per widget. In
    // the editor the whole surface takes input and nothing is blurred (the
    // backdrop is opaque: niri's glass would only be drawn under it).
    mask: Region { id: inputMask }
    BlurKick { id: blurKick; window: root }
    BackgroundEffect.blurRegion: Materials.wantsRegion("widgets", blurKick.screen) && !blurKick.on && !root.editing ? effect : blurKick.none
    Region { id: effect }
    // Off the screen's top-left pixel: the top-left hot corner sits there, under this layer.
    Item { id: dot; x: 2; y: 2; width: 1; height: 1 }
    Region { id: dotRegion; item: dot }
    // A Region follows its item's own geometry, never a parent's transform:
    // regions on the frames themselves stayed where the stage was when they
    // were made, and on the way out of the editor niri's glass sat on the
    // small stage while the widgets zoomed home, then jumped under them. So
    // each frame has a piece out here, bound to where the stage's transform
    // (and the frame's own settle-in scale, about its centre) puts it on
    // screen: the regions move with every frame of the zoom.
    Item { id: pieceLayer }
    Component {
        id: pieceComp
        Item {
            id: piece
            property Item frame
            readonly property real s: frame ? stage.scale * frame.scale : 0
            x: frame ? stage.x + (frame.x + frame.width * (1 - frame.scale) / 2) * stage.scale : 0
            y: frame ? stage.y + (frame.y + frame.height * (1 - frame.scale) / 2) * stage.scale : 0
            width: frame ? frame.width * s : 0
            height: frame ? frame.height * s : 0
            readonly property Region input: Region { item: piece }
            readonly property Region glass: Region { item: piece; radius: piece.frame ? piece.frame.radius * piece.s : 0 }
        }
    }
    function rebuildRegions() {
        const old = pieceLayer.children.slice();
        const frames = [];
        for (let i = 0; i < frameRepeater.count; i++) if (frameRepeater.itemAt(i)) frames.push(frameRepeater.itemAt(i));
        const pieces = frames.map(f => pieceComp.createObject(pieceLayer, { frame: f }));
        inputMask.item = editing ? catcher : null;
        // Every widget takes input (a right-click opens the editor); what a
        // non-interactive one gets, it ignores.
        inputMask.regions = editing ? [] : pieces.map(p => p.input);
        // A bare widget is its own glass: niri blurs nothing behind it.
        const plated = pieces.filter(p => !p.frame.bare);
        effect.regions = plated.length ? plated.map(p => p.glass) : [dotRegion];   // never an empty region
        for (const p of old) p.destroy();
    }
    onEditingChanged: {
        animateEditor();
        Qt.callLater(rebuildRegions);
        dragDelta = null;
        if (editing && focused_) keys.forceActiveFocus();
    }
    Component.onCompleted: { syncModel(); Qt.callLater(rebuildRegions); }

    // ------------------------------------------------------- wallpaper ---
    // What glass widgets (the clock's digits) look through: the wallpaper as
    // WallpaperView draws it — the same crop, the same parallax slice — so the
    // picture bends through the digits at their rims. Loaded while such a
    // widget is on this screen, and in the editor (the stage shows it).
    readonly property bool wantsGlass: items.some(i => W.bare(i.type, W.withDefaults(i.type, i.options, WidgetEditor.custom)))
    readonly property string wallPath: LockLib.lockBackground(Wallpaper.pathFor(screen.name),
        (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/vitrum/poster.png")
    readonly property string wallUrl: wallPath ? "file://" + wallPath + "?" + wallStamp : ""
    // A video's poster is written by vitrum-theme a moment after the wallpaper
    // changes, under the same name every time: read again then, and retried
    // while it is not there yet (a failed load never tried again: no glass).
    property int wallStamp: 0
    readonly property string wallRaw: Wallpaper.pathFor(screen.name)
    onWallRawChanged: { wallStamp++; wallSettle.restart(); }
    Timer { id: wallSettle; interval: 4000; onTriggered: root.wallStamp++ }
    Timer { id: wallRetry; interval: 1500; onTriggered: root.wallStamp++ }
    readonly property real wallExtra: Wallpaper.parallax ? height * 0.12 : 0
    readonly property var wallSpaces: Niri.workspacesOn(screen.name)
    Item {
        id: wallGlass
        anchors.fill: parent
        visible: false
        Item {
            width: parent.width
            height: parent.height + root.wallExtra
            y: WallLib.parallaxOffset(Math.max(0, root.wallSpaces.findIndex(w => w.active)), root.wallSpaces.length, root.wallExtra)
            Behavior on y { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }
            // A plain image, as the lock's clear glass has: an effect nested in
            // this hidden item never drew, and the digits came out flat grey.
            Image {
                anchors.fill: parent
                source: root.wantsGlass || root.editing ? root.wallUrl : ""
                cache: false
                onStatusChanged: if (status === Image.Error) wallRetry.restart()
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(width, height)
            }
        }
    }
    ShaderEffectSource { id: wallGlassTex; sourceItem: root.wantsGlass || root.editing ? wallGlass : null; visible: false; hideSource: false }

    // ---------------------------------------------------------- editor ---
    // Two parts, one after the other, never at once:
    //   fade  0..1  the backdrop and the stage's wallpaper copy cover the desktop
    //   zoom  0..1  the stage shrinks from the whole screen into its place
    // In: fade, then zoom. Out: zoom, then fade. The copy is opaque whenever it
    // is not where the real wallpaper (awww, WallpaperView) is, and fades only
    // at home, right over it: zooming a half-faded copy laid a smaller second
    // wallpaper over the real one for most of the way out.
    property real fade: 0
    property real zoom: 0
    // t: anything of the editor on screen (0 the desktop as it is).
    readonly property real t: Math.max(fade, zoom)
    readonly property int fadeMs: Motion.fast
    readonly property int zoomMs: Motion.emphasized
    function animateEditor() {
        enterAnim.stop(); leaveAnim.stop();
        if (!Motion.enabled) { fade = zoom = editing ? 1 : 0; return; }
        // From wherever an interrupted one left them: the part already done takes no time.
        if (editing) { enterFade.duration = Math.round(fadeMs * (1 - fade)); enterZoom.duration = Math.round(zoomMs * (1 - zoom)); enterAnim.start(); }
        else { leaveZoom.duration = Math.round(zoomMs * zoom); leaveFade.duration = Math.round(fadeMs * fade); leaveAnim.start(); }
    }
    SequentialAnimation {
        id: enterAnim
        NumberAnimation { id: enterFade; target: root; property: "fade"; to: 1; easing.type: Easing.OutCubic }
        NumberAnimation { id: enterZoom; target: root; property: "zoom"; to: 1; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: leaveAnim
        NumberAnimation { id: leaveZoom; target: root; property: "zoom"; to: 0; easing.type: Easing.OutCubic }
        NumberAnimation { id: leaveFade; target: root; property: "fade"; to: 0; easing.type: Easing.OutCubic }
    }
    readonly property bool hasSheet: focused_
    readonly property real sheetW: Math.round(Math.max(340, Math.min(420, width * 0.23)))
    readonly property real margin: Tokens.gap * 2
    readonly property var st: W.stageRect(bounds, sheetW, 0.72, hasSheet, margin)

    // Behind it all, opaque: the windows are gone while the desktop is edited.
    // Only around a stage that has left home: at home the copy covers it all,
    // and this one, blurred and dark, showed through the copy as it faded.
    Item {
        anchors.fill: parent
        visible: root.zoom > 0.001 && root.fade > 0.001
        opacity: root.fade
        Rectangle { anchors.fill: parent; color: Colors.bg }
        MultiEffect {
            anchors.fill: parent
            source: wallGlassTex
            blurEnabled: true; blurMax: 64; blur: 1
            brightness: Colors.dark ? -0.18 : -0.05
            saturation: 0.1
        }
        Rectangle { anchors.fill: parent; color: Colors.alpha(Colors.bg, 0.35) }
    }
    // A click on the backdrop: nothing selected.
    MouseArea { id: catcher; anchors.fill: parent; enabled: root.editing; onClicked: WidgetEditor.clearSelection() }

    Item {
        id: stage
        width: root.width; height: root.height
        transformOrigin: Item.TopLeft
        x: root.st.x * root.zoom
        y: root.st.y * root.zoom
        scale: 1 + (root.st.scale - 1) * root.zoom
        // What the glass widgets (the clock's digits) look through: the
        // wallpaper where this stage draws it, scaled and moved with it. At
        // home it is where the real wallpaper is.
        Item { id: stageWall; anchors.fill: parent }

        // The desktop as it is, small: the wallpaper with rounded corners and a shadow.
        Rectangle { id: stageMask; anchors.fill: parent; radius: stageShadow.radius; visible: false; layer.enabled: true }
        Rectangle {
            id: stageShadow
            anchors.fill: parent
            visible: root.zoom > 0.001 && root.fade > 0.001
            opacity: root.fade
            // Square at home: the copy covers the real wallpaper edge to edge.
            radius: Tokens.radiusPanel * 1.5 * root.zoom / Math.max(0.3, stage.scale)
            color: Colors.surface
            layer.enabled: visible
            layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 1; shadowOpacity: 0.55; shadowVerticalOffset: 18; shadowColor: "black" }
        }
        Item {
            anchors.fill: parent
            visible: root.fade > 0.001
            opacity: root.fade
            layer.enabled: visible
            layer.effect: MultiEffect { maskEnabled: true; maskSource: stageMask }
            ShaderEffectSource { anchors.fill: parent; sourceItem: wallGlass; live: true }
            // A faint grid: where widgets snap (on the stage, not at home).
            Canvas {
                anchors.fill: parent
                opacity: root.zoom
                onPaint: {
                    const c = getContext("2d"), s = 88;
                    c.reset();
                    c.fillStyle = Qt.rgba(1, 1, 1, 0.16);
                    for (let x = s; x < width; x += s) for (let y = s; y < height; y += s) c.fillRect(x - 1.5, y - 1.5, 3, 3);
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }
        }

        // A rubber band from empty space selects what it touches (Shift: adds).
        MouseArea {
            id: bandArea
            anchors.fill: parent
            enabled: root.editing
            property point a
            property bool additive: false
            property var rect: null
            onPressed: m => { a = Qt.point(m.x, m.y); additive = (m.modifiers & Qt.ShiftModifier) !== 0; rect = null; keys.forceActiveFocus(); }
            onPositionChanged: m => {
                if (!pressed) return;
                rect = { x: Math.min(a.x, m.x), y: Math.min(a.y, m.y), w: Math.abs(m.x - a.x), h: Math.abs(m.y - a.y) };
            }
            onReleased: {
                if (!rect || rect.w + rect.h < 6) { if (!additive) WidgetEditor.clearSelection(); rect = null; return; }
                const r = rect, hit = root.items.filter(i => i.x < r.x + r.w && i.x + i.w > r.x && i.y < r.y + r.h && i.y + i.h > r.y).map(i => i.id);
                WidgetEditor.selectOnly(additive ? Array.from(new Set(WidgetEditor.selection.concat(hit))) : hit);
                rect = null;
            }
        }
        Rectangle {
            visible: bandArea.rect !== null
            x: bandArea.rect ? bandArea.rect.x : 0; y: bandArea.rect ? bandArea.rect.y : 0
            width: bandArea.rect ? bandArea.rect.w : 0; height: bandArea.rect ? bandArea.rect.h : 0
            radius: Tokens.radiusButton / stage.scale
            color: Colors.alpha(Colors.accent, 0.14)
            border.width: 1.5 / stage.scale; border.color: Colors.accent
            z: 5
        }

        Repeater {
            id: frameRepeater
            model: idModel
            onItemAdded: Qt.callLater(root.rebuildRegions)
            onItemRemoved: Qt.callLater(root.rebuildRegions)
            delegate: WidgetFrame {
                required property string wid
                modelData: root.byId[wid] || ({ id: wid, type: "", x: 0, y: 0, w: 1, h: 1, options: {} })
                editing: root.editing
                selected: root.editing && WidgetEditor.selection.indexOf(wid) >= 0
                offset: selected ? root.dragDelta : null
                bounds: root.bounds
                grid: root.grid
                ui: 1 / Math.max(0.3, stage.scale)
                others: root.items.filter(i => WidgetEditor.selection.indexOf(i.id) < 0 && i.id !== wid)
                glassBackdrop: stageWall
                glassSource: wallGlassTex
                onPicked: additive => { WidgetEditor.select(wid, additive); keys.forceActiveFocus(); }
                onDragMoved: (dx, dy) => root.dragTo(wid, dx, dy)
                onDragEnded: (dx, dy, p) => root.dropAt(wid, dx, dy, p)
                onResized: r => WidgetEditor.patch(wid, r)
                onRemoved: WidgetEditor.remove(wid)
                onOptionsEdited: o => WidgetEditor.setOptions(wid, o)
                onEditRequested: { UiState.closeAll(); UiState.widgetsEdit = true; Qt.callLater(() => WidgetEditor.select(wid, false)); }
            }
        }

        // A gallery card being dragged in: where it would land, tinted glass
        // with an accent outline.
        Rectangle {
            id: ghost
            visible: root.editing && WidgetEditor.dragType !== "" && ghostPos !== null
            property var ghostPos: null
            readonly property var size: W.defaultSize(WidgetEditor.dragType || "clock", WidgetEditor.custom)
            width: size.w; height: size.h
            x: ghostPos ? ghostPos.x - width / 2 : 0
            y: ghostPos ? ghostPos.y - height / 2 : 0
            radius: Tokens.radiusPanel * 1.25
            color: "transparent"
            border.width: 2 / stage.scale; border.color: Colors.accent
            z: 6
            ShellTint { anchors.fill: parent; z: -1; radius: parent.radius; group: "widgets"; rim: false; active: ghost.visible }
        }
    }

    // ---------------------------------------------------- moving the selection
    // The dragged widget lines up with the rest (W.align); the others in the
    // selection keep their places relative to it.
    property var dragDelta: null
    function dragTo(id, dx, dy) {
        const p = byId[id];
        if (!p) return;
        const f = frameFor(id);
        const target = f ? f.fit({ x: p.x + dx, y: p.y + dy, w: p.w, h: p.h }, "move") : { x: p.x + dx, y: p.y + dy };
        dragDelta = { dx: target.x - p.x, dy: target.y - p.y };
    }
    function dropAt(id, dx, dy, windowPos) {
        const d = dragDelta;
        dragDelta = null;
        // Past the edge, onto another screen (one widget at a time; one on
        // every screen is there already).
        const to = W.dropTarget(Niri.outputs, screen.name, windowPos, sheetW, 0.72, margin);
        if (to && WidgetEditor.selection.length <= 1 && byId[id] && byId[id].output !== W.EVERY) {
            const it = byId[id];
            WidgetEditor.moveToOutput(id, to.output, { x: to.x - it.w / 2, y: to.y - it.h / 2 });
            return;
        }
        if (!d) return;
        const patches = {};
        for (const sid of WidgetEditor.selection) {
            const it = byId[sid];
            if (!it) continue;
            const r = W.place({ x: it.x + d.dx, y: it.y + d.dy, w: it.w, h: it.h }, bounds, grid, { w: 120, h: 80 });
            patches[sid] = { x: r.x, y: r.y };
        }
        WidgetEditor.patchMany(patches);
    }
    function frameFor(id) {
        for (let i = 0; i < frameRepeater.count; i++) { const f = frameRepeater.itemAt(i); if (f && f.wid === id) return f; }
        return null;
    }
    function nudge(dx, dy) {
        const patches = {};
        for (const sid of WidgetEditor.selection) {
            const it = byId[sid];
            if (!it) continue;
            const r = W.place({ x: it.x + dx, y: it.y + dy, w: it.w, h: it.h }, bounds, 1, { w: 120, h: 80 });
            patches[sid] = { x: r.x, y: r.y };
        }
        WidgetEditor.patchMany(patches);
    }

    // ----------------------------------------------------------- sheet ---
    // Made only while editing, on the focused screen: its gallery is a dozen
    // live widgets, which have no business running the rest of the time.
    Loader {
        active: root.hasSheet && (root.editing || root.t > 0.001)
        sourceComponent: sheetComponent
    }
    Component {
        id: sheetComponent
        EditorSheet {
            id: sheet
            x: root.margin - (1 - root.zoom) * (width + root.margin)
            y: root.margin
            width: root.sheetW
            height: root.height - 2 * root.margin
            opacity: root.zoom
            screenName: root.screen.name
            barSpace: root.barSpace
            onCardDragged: p => {
                const s = stage.mapFromItem(null, p.x, p.y);
                ghost.ghostPos = s.x >= 0 && s.y >= 0 && s.x <= stage.width && s.y <= stage.height ? s : null;
            }
            onCardDropped: (type, p) => {
                const s = stage.mapFromItem(null, p.x, p.y);
                ghost.ghostPos = null;
                if (s.x >= 0 && s.y >= 0 && s.x <= stage.width && s.y <= stage.height) WidgetEditor.addAt(type, root.screen.name, s.x, s.y);
            }
        }
    }

    Item {
        id: keys
        focus: root.editing && root.focused_
        Keys.onPressed: e => {
            const ctrl = (e.modifiers & Qt.ControlModifier) !== 0, shift = (e.modifiers & Qt.ShiftModifier) !== 0;
            const step = root.grid * (shift ? 4 : 1);
            if (e.key === Qt.Key_Escape) WidgetEditor.cancel();
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) WidgetEditor.done();
            else if (e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace) WidgetEditor.removeSelected();
            else if (ctrl && e.key === Qt.Key_Z && shift) WidgetEditor.redo();
            else if (ctrl && e.key === Qt.Key_Z) WidgetEditor.undo();
            else if (ctrl && e.key === Qt.Key_Y) WidgetEditor.redo();
            else if (ctrl && e.key === Qt.Key_D) WidgetEditor.duplicateSelected();
            else if (ctrl && e.key === Qt.Key_A) WidgetEditor.selectOnly(root.items.map(i => i.id));
            else if (e.key === Qt.Key_Left) root.nudge(-step, 0);
            else if (e.key === Qt.Key_Right) root.nudge(step, 0);
            else if (e.key === Qt.Key_Up) root.nudge(0, -step);
            else if (e.key === Qt.Key_Down) root.nudge(0, step);
            else return;
            e.accepted = true;
        }
    }
}
