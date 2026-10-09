import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.components
import "widgets"
import "../../lib/widgets.js" as W
import "../../lib/wallpaper.js" as WallLib
import "../../lib/lock.js" as LockLib

/*
 * Desktop widgets, one surface per screen, under the windows (bottom layer,
 * above the wallpaper). Widgets come from widgets.items, kept per output name.
 *
 * Outside edit mode only the widgets with controls (notes, media, shortcuts)
 * take input; everything else lets clicks through to the desktop.
 *
 * Edit mode (vitrum-ipc widgets edit, or the launcher): the surface rises
 * above the windows; drag to move, the corner to resize — both snap to the
 * grid —, × to remove, the gallery at the bottom to add. Escape or Done.
 */
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property bool editing: UiState.widgetsEdit
    readonly property bool focused_: screen.name === (Niri.focusedOutput || Quickshell.screens[0].name)
    readonly property int grid: Tokens.gap
    readonly property var bounds: ({ w: width, h: height })
    readonly property int barSpace: Settings.get("bar.position", "top") === "top" ? Tokens.islandHeight + 2 * Tokens.gap : 0

    // Hand-written entries without an id get stable ones (by position), not fresh ones per change.
    readonly property var allItems: { let n = 0; return W.sanitize(Settings.get("widgets.items", []), () => "auto" + (n++)); }
    readonly property var items: W.forOutput(allItems, screen.name)
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
    function newId() { return Date.now().toString(36) + Math.floor(Math.random() * 1e6).toString(36); }
    function save(list) { Settings.set("widgets.items", list); }
    function patch(id, p) { save(W.update(allItems, id, p)); }
    Connections {
        target: UiState
        function onWidgetAddRequested(type) { if (root.focused_) root.save(W.add(root.allItems, type, root.screen.name, root.bounds, root.grid, root.barSpace, root.newId)); }
    }

    visible: true
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "vitrum-widgets"
    WlrLayershell.layer: editing ? WlrLayer.Top : WlrLayer.Bottom
    WlrLayershell.keyboardFocus: editing && focused_ ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

    // Input and blur follow the widgets: one rounded region per widget.
    mask: Region { id: inputMask }
    BlurKick { id: blurKick; window: root }
    BackgroundEffect.blurRegion: Materials.wantsRegion("widgets") && !blurKick.on ? effect : blurKick.none
    Region { id: effect }
    Item { id: dot; width: 1; height: 1 }
    Component { id: regionComp; Region {} }
    function rebuildRegions() {
        for (const r of inputMask.regions) r.destroy();
        for (const r of effect.regions) r.destroy();
        const frames = [];
        for (let i = 0; i < frameRepeater.count; i++) if (frameRepeater.itemAt(i)) frames.push(frameRepeater.itemAt(i));
        inputMask.item = editing ? catcher : null;
        inputMask.regions = editing ? [] : frames.filter(f => W.interactive(f.modelData.type)).map(f => regionComp.createObject(inputMask, { item: f }));
        // A bare widget is its own glass: niri blurs nothing behind it.
        const plated = frames.filter(f => !W.bare(f.modelData.type));
        effect.regions = plated.length ? plated.map(f => regionComp.createObject(effect, { item: f, radius: Tokens.radiusPanel }))
                                       : [regionComp.createObject(effect, { item: dot })];   // never an empty region
    }
    // Editing happens on a clear desktop: windows (Settings, which opened it)
    // went on showing through the grid and covered the widgets. The screen's
    // empty workspace (niri keeps one last) while editing, then back.
    property int editFrom: -1
    onEditingChanged: {
        Qt.callLater(rebuildRegions);
        if (editing && focused_) keys.forceActiveFocus();
        if (!focused_) return;
        if (editing) {
            const cur = Niri.workspaces[Niri.focusedWorkspaceId];
            const list = Niri.workspacesOn(screen.name);
            if (cur && Niri.windowsOn(cur.id).length > 0 && list.length) {
                editFrom = cur.id;
                Niri.focusWorkspace(list[list.length - 1].idx);
            }
        } else if (editFrom >= 0) {
            const back = Niri.workspaces[editFrom];
            if (back) Niri.focusWorkspace(back.idx);
            editFrom = -1;
        }
    }
    Component.onCompleted: { syncModel(); Qt.callLater(rebuildRegions); }

    // What glass widgets (the clock's digits) look through: the wallpaper as
    // WallpaperView draws it — the same crop, the same parallax slice — so the
    // picture bends through the digits at their rims. Loaded only while such a
    // widget is on this screen.
    readonly property bool wantsGlass: items.some(i => W.bare(i.type))
    readonly property string wallPath: LockLib.lockBackground(Wallpaper.pathFor(screen.name),
        (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/vitrum/poster.png")
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
                source: root.wantsGlass && root.wallPath ? "file://" + root.wallPath + "?" + root.wallStamp : ""
                cache: false
                onStatusChanged: if (status === Image.Error) wallRetry.restart()
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(width, height)
            }
        }
    }
    ShaderEffectSource { id: wallGlassTex; sourceItem: root.wantsGlass ? wallGlass : null; visible: false; hideSource: false }

    // Edit mode: a faint grid, and a catcher that takes the whole screen.
    MouseArea { id: catcher; anchors.fill: parent; enabled: root.editing }
    Canvas {
        anchors.fill: parent
        opacity: root.editing ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { enabled: Motion.enabled; EaseAnim {} }
        onPaint: {
            const c = getContext("2d"), s = root.grid * 4;
            c.reset();
            c.fillStyle = Qt.rgba(0, 0, 0, 0.25); c.fillRect(0, 0, width, height);
            c.fillStyle = Qt.rgba(1, 1, 1, 0.18);
            for (let x = s; x < width; x += s) for (let y = s; y < height; y += s) c.fillRect(x - 1, y - 1, 2, 2);
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
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
            bounds: root.bounds
            grid: root.grid
            others: root.items.filter(i => i.id !== wid)
            glassBackdrop: wallGlass
            glassSource: wallGlassTex
            onMoved: r => root.patch(wid, r)
            onRemoved: root.save(W.remove(root.allItems, wid))
            onOptionsEdited: o => root.patch(wid, { options: o })
        }
    }

    // ------------------------------------------------------- gallery ---
    Surface {
        id: gallery
        visible: opacity > 0 && root.focused_
        opacity: root.editing ? 1 : 0
        Behavior on opacity { enabled: Motion.enabled; EaseAnim {} }
        group: "overlay"
        radius: height / 2
        width: galleryRow.implicitWidth + 2 * Tokens.padding
        height: Tokens.islandHeight * 1.6
        anchors.horizontalCenter: parent.horizontalCenter
        // Just above the dock (or the bottom edge): widgets start at the top left.
        y: parent.height - height - Tokens.gap * 3
           - (Settings.get("dock.enabled", true) ? Settings.get("dock.iconSize", 44) + 2 * Tokens.padding + Tokens.gap * 2 : 0)
        Row {
            id: galleryRow
            anchors.centerIn: parent
            spacing: Tokens.gap / 2
            Label { text: "Add"; role: "dim"; anchors.verticalCenter: parent.verticalCenter; rightPadding: Tokens.gap }
            Repeater {
                model: [
                    { type: "clock", icon: "clock", name: "Clock" }, { type: "calendar", icon: "calendar", name: "Calendar" },
                    { type: "weather", icon: "weather-partly", name: "Weather" }, { type: "system", icon: "cpu", name: "System" },
                    { type: "media", icon: "music", name: "Media" }, { type: "notes", icon: "edit", name: "Notes" },
                    { type: "shortcuts", icon: "apps", name: "Apps" }, { type: "battery", icon: "battery", name: "Battery" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    height: Tokens.islandHeight * 1.15
                    width: addRow.implicitWidth + Tokens.padding * 1.4
                    radius: height / 2
                    color: addMouse.containsMouse ? Colors.alpha(Colors.accent, 0.25) : "transparent"
                    Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
                    Row { id: addRow; anchors.centerIn: parent; spacing: 4
                          Icon { name: modelData.icon; anchors.verticalCenter: parent.verticalCenter }
                          Label { text: modelData.name; anchors.verticalCenter: parent.verticalCenter } }
                    MouseArea { id: addMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.save(W.add(root.allItems, modelData.type, root.screen.name, root.bounds, root.grid, root.barSpace, root.newId)) }
                }
            }
            Rectangle { width: 1; height: Tokens.islandHeight * 0.8; color: Colors.alpha(Colors.text, 0.15); anchors.verticalCenter: parent.verticalCenter }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: Tokens.islandHeight * 1.15; width: doneLabel.implicitWidth + Tokens.padding * 2; radius: height / 2
                color: Colors.accent
                Label { id: doneLabel; anchors.centerIn: parent; text: "Done"; role: "onAccent"; font.weight: Font.DemiBold }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: UiState.widgetsEdit = false }
            }
        }
    }
    Item { id: keys; focus: root.editing; Keys.onEscapePressed: UiState.widgetsEdit = false }
}
