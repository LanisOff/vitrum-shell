import QtQuick
import qs.services
import qs.theme
import qs.components
import "../../lib/widgets.js" as W

/*
 * One widget: its plate, its content by type, and in the editor the handles.
 *
 * The content gets the widget contract: options (with the schema's defaults
 * filled in), sizeClass (S/M/L/XL, from the size it has now), preview (false
 * here) — and its optionsEdited reaches the editor. A type that cannot be
 * shown (a custom widget deleted, a file that fails) is a "Missing widget"
 * plate that can still be selected and removed.
 *
 * Geometry is in desktop coordinates, whatever the stage's scale: drags are
 * read in the parent's (the stage's) frame. A move is reported as a delta
 * (the Desktop moves the whole selection and lines it up); a resize as the
 * new rectangle, both on release.
 */
Surface {
    id: frame
    property var modelData: ({ type: "", x: 0, y: 0, w: 1, h: 1, options: {} })
    property bool editing: false
    property bool selected: false
    /// The selection's live move ({ dx, dy }) while it is dragged, else null.
    property var offset: null
    property var bounds: ({ w: 0, h: 0 })
    property int grid: 8
    property var others: []
    /// 1 / the stage's scale: handles keep their size on screen.
    property real ui: 1
    readonly property var alignOpts: ({ threshold: 12, gap: 16 })
    function fit(r, kind) {
        const placed = W.place(r, bounds, grid, { w: 120, h: 80 });
        return W.place(W.align(placed, others, kind, alignOpts), bounds, grid, { w: 120, h: 80 });
    }
    signal picked(bool additive)
    signal dragMoved(real dx, real dy)
    signal dragEnded(real dx, real dy, point windowPos)
    signal resized(var rect)
    signal removed()
    signal optionsEdited(var options)
    /// Right-click outside the editor: open it on this widget.
    signal editRequested()

    readonly property var meta: W.meta(modelData.type, WidgetEditor.custom)
    readonly property var options: W.withDefaults(modelData.type, modelData.options, WidgetEditor.custom)

    // While resizing, the live rectangle; while the selection moves, shifted.
    property var live: null
    readonly property var r: live ? live
        : offset ? ({ x: modelData.x + offset.dx, y: modelData.y + offset.dy, w: modelData.w, h: modelData.h })
        : modelData
    x: r.x; y: r.y; width: r.w; height: r.h
    readonly property string sizeClass: W.sizeClass(r.w, r.h)
    /// What glass content looks through (Desktop's wallpaper copy), and its texture.
    property Item glassBackdrop: null
    property Item glassSource: null
    readonly property bool bare: W.bare(modelData.type, options)
    group: "widgets"
    color: bare ? (editing ? Colors.alpha(Colors.surface, 0.25) : "transparent") : Materials.fill("widgets", 0)
    radius: Tokens.radiusPanel * 1.25
    border.width: editing ? (selected ? 2.5 * ui : Tokens.hairline * ui) : bare ? 0 : Tokens.hairline
    border.color: editing && selected ? Colors.accent : editing ? Colors.alpha(Colors.text, 0.35) : Materials.border("widgets")
    z: selected ? 2 : 1

    // Appears with a small pop.
    scale: 0.92; opacity: 0
    Component.onCompleted: { scale = 1; opacity = 1; UiState.widgetFramesMade++; }
    Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.bouncy } }
    Behavior on opacity { enabled: Motion.enabled; EaseAnim {} }

    // The file that shows it (W.widgetFile); none for a missing type.
    readonly property string file: meta.missing ? "" : W.widgetFile(modelData.type)

    Loader {
        id: content
        anchors.fill: parent
        anchors.margins: frame.bare ? 0 : Tokens.padding
        source: frame.file ? Qt.resolvedUrl("widgets/" + frame.file) : ""
        enabled: !frame.editing
        visible: status === Loader.Ready
        onLoaded: {
            item.options = Qt.binding(() => frame.options);
            if (item.hasOwnProperty("sizeClass")) item.sizeClass = Qt.binding(() => frame.sizeClass);
            if (item.hasOwnProperty("preview")) item.preview = false;
            if (item.hasOwnProperty("type")) item.type = Qt.binding(() => frame.modelData.type);
            if (item.hasOwnProperty("backdrop")) {
                item.backdrop = Qt.binding(() => frame.glassBackdrop);
                item.source = Qt.binding(() => frame.glassSource);
            }
            if (item.optionsEdited) item.optionsEdited.connect(o => frame.optionsEdited(o));
        }
    }
    WidgetEmpty {
        visible: content.status !== Loader.Ready && content.status !== Loader.Loading
        icon: "help"
        text: frame.meta.missing ? "Missing widget" : frame.meta.name + " could not load"
    }

    // Outside the editor: right-click → the editor, this widget selected. The
    // rest of the clicks belong to the content (or pass through).
    MouseArea {
        anchors.fill: parent
        enabled: !frame.editing
        acceptedButtons: Qt.RightButton
        onClicked: frame.editRequested()
    }

    // ------------------------------------------------------- editing ---
    MouseArea {
        id: mover
        anchors.fill: parent
        enabled: frame.editing
        hoverEnabled: true
        cursorShape: pressed && moved ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property point start
        property bool moved: false
        property real dx: 0
        property real dy: 0
        onPressed: m => {
            start = mapToItem(frame.parent, m.x, m.y);
            moved = false; dx = 0; dy = 0;
            const add = (m.modifiers & Qt.ShiftModifier) !== 0;
            if (add || !frame.selected) frame.picked(add);
        }
        onPositionChanged: m => {
            if (!pressed) return;
            const p = mapToItem(frame.parent, m.x, m.y);
            dx = p.x - start.x; dy = p.y - start.y;
            if (!moved && Math.hypot(dx, dy) < 4) return;
            moved = true;
            frame.dragMoved(dx, dy);
        }
        onReleased: m => { if (moved) frame.dragEnded(dx, dy, mapToItem(null, m.x, m.y)); }
    }
    // A hover lift, so the hand knows what it is about to take.
    Rectangle {
        anchors.fill: parent; radius: parent.radius
        visible: frame.editing && mover.containsMouse && !frame.selected
        color: Colors.alpha(Colors.text, 0.06)
    }
    Rectangle {
        id: grip
        visible: frame.editing && frame.selected
        width: 20 * frame.ui; height: width; radius: width / 2
        anchors { right: parent.right; bottom: parent.bottom; margins: -7 * frame.ui }
        color: Colors.accent
        Icon { anchors.centerIn: parent; name: "resize"; size: 12 * frame.ui; color: Colors.onAccent; rotation: 90 }
        MouseArea {
            anchors.fill: parent; anchors.margins: -6 * frame.ui
            cursorShape: Qt.SizeFDiagCursor
            property point start
            property var origin
            onPressed: m => { start = mapToItem(frame.parent, m.x, m.y); origin = { x: frame.r.x, y: frame.r.y, w: frame.r.w, h: frame.r.h }; }
            onPositionChanged: m => {
                const p = mapToItem(frame.parent, m.x, m.y);
                frame.live = frame.fit({ x: origin.x, y: origin.y, w: origin.w + p.x - start.x, h: origin.h + p.y - start.y }, "resize");
            }
            onReleased: frame.commitResize()
        }
    }
    Rectangle {
        visible: frame.editing && (frame.selected || mover.containsMouse)
        width: 24 * frame.ui; height: width; radius: width / 2
        anchors { right: parent.right; top: parent.top; margins: -9 * frame.ui }
        color: closeMouse.containsMouse ? Colors.danger : Materials.fill("overlay", 2)
        border.width: Tokens.hairline * frame.ui; border.color: Materials.border("overlay")
        Icon { anchors.centerIn: parent; name: "close"; size: 14 * frame.ui; color: closeMouse.containsMouse ? "white" : Colors.text }
        MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: frame.removed() }
    }

    function commitResize() {
        if (!live) return;
        const r = live;
        resized({ x: r.x, y: r.y, w: r.w, h: r.h });
        // Kept until the saved rectangle arrives, so it does not jump back.
        Qt.callLater(() => frame.live = null);
    }
}
