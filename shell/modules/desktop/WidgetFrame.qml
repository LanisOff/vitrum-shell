import QtQuick
import qs.services
import qs.theme
import qs.components
import "widgets"
import "../../lib/widgets.js" as W

/*
 * One widget: its material, its content by type, and in edit mode the
 * handles. Moves and resizes are shown live and saved on release, snapped.
 */
Surface {
    id: frame
    property var modelData: ({ type: "", x: 0, y: 0, w: 1, h: 1, options: {} })
    property bool editing: false
    property var bounds: ({ w: 0, h: 0 })
    property int grid: 8
    /// The other widgets on this screen: edges line up with theirs (W.align).
    property var others: []
    readonly property var alignOpts: ({ threshold: 12, gap: grid * 2 })
    function fit(r, kind) {
        const placed = W.place(r, bounds, grid, { w: 120, h: 80 });
        return W.place(W.align(placed, others, kind, alignOpts), bounds, grid, { w: 120, h: 80 });
    }
    signal moved(var rect)
    signal removed()
    signal optionsEdited(var options)

    // While dragging, the live rectangle; otherwise the stored one.
    property var live: null
    readonly property var r: live || modelData
    x: r.x; y: r.y; width: r.w; height: r.h
    /// What glass content looks through (Desktop's wallpaper copy), and its texture.
    property Item glassBackdrop: null
    property Item glassSource: null
    // No plate: the content is its own glass. In edit mode the outline shows where it is.
    readonly property bool bare: W.bare(modelData.type)
    group: "widgets"
    color: bare ? (editing ? Colors.alpha(Colors.surface, 0.25) : "transparent") : Materials.fill("widgets", 0)
    radius: Tokens.radiusPanel
    border.width: editing ? 2 : bare ? 0 : Tokens.hairline
    border.color: editing ? Colors.alpha(Colors.accent, 0.8) : Materials.border("widgets")

    // Appears with a small pop.
    scale: 0.92; opacity: 0
    Component.onCompleted: { scale = 1; opacity = 1; UiState.widgetFramesMade++; }
    Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.bouncy } }
    Behavior on opacity { enabled: Motion.enabled; EaseAnim {} }

    // Soft and colourful: each type its own turn of the accent, as a diagonal
    // gradient under white content. Types without one keep the material.
    readonly property var tones: ({})
    readonly property bool toned: tones[modelData.type] !== undefined
    readonly property color tone: toned ? Colors.tone(tones[modelData.type]) : "transparent"
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: frame.toned
        opacity: 0.92
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0; color: Colors.tone(frame.tones[frame.modelData.type] || 0, 0.08) }
            GradientStop { position: 1; color: Colors.tone((frame.tones[frame.modelData.type] || 0) + 18, -0.06) }
        }
    }

    readonly property var contents: ({
        clock: clockC, calendar: calendarC, weather: weatherC, system: systemC,
        media: mediaC, notes: notesC, shortcuts: shortcutsC, battery: batteryC, monitor: monitorC
    })
    Component { id: clockC; ClockWidget {} }
    Component { id: calendarC; CalendarWidget {} }
    Component { id: weatherC; WeatherWidget {} }
    Component { id: systemC; SystemWidget {} }
    Component { id: mediaC; MediaWidget {} }
    Component { id: notesC; NotesWidget { onOptionsEdited: o => frame.optionsEdited(o) } }
    Component { id: shortcutsC; ShortcutsWidget {} }
    Component { id: batteryC; BatteryWidget {} }
    Component { id: monitorC; MonitorWidget {} }

    Loader {
        id: content
        anchors.fill: parent
        anchors.margins: Tokens.padding
        sourceComponent: frame.contents[frame.modelData.type] || null
        enabled: !frame.editing
        onLoaded: {
            item.options = Qt.binding(() => frame.modelData.options || {});
            if (item.hasOwnProperty("toned")) item.toned = Qt.binding(() => frame.toned);
            if (item.hasOwnProperty("backdrop")) {
                item.backdrop = Qt.binding(() => frame.glassBackdrop);
                item.source = Qt.binding(() => frame.glassSource);
            }
        }
    }

    // ------------------------------------------------------- editing ---
    MouseArea {
        id: mover
        anchors.fill: parent
        enabled: frame.editing
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property point start
        property var origin
        onPressed: m => { start = mapToItem(null, m.x, m.y); origin = { x: frame.r.x, y: frame.r.y, w: frame.r.w, h: frame.r.h }; }
        onPositionChanged: m => {
            const p = mapToItem(null, m.x, m.y);
            frame.live = frame.fit({ x: origin.x + p.x - start.x, y: origin.y + p.y - start.y, w: origin.w, h: origin.h }, "move");
        }
        onReleased: frame.commit()
    }
    Rectangle {
        id: grip
        visible: frame.editing
        width: 18; height: 18; radius: 9
        anchors { right: parent.right; bottom: parent.bottom; margins: -6 }
        color: Colors.accent
        Icon { anchors.centerIn: parent; name: "expand"; size: 12; color: Colors.onAccent; rotation: -45 }
        MouseArea {
            anchors.fill: parent; anchors.margins: -6
            cursorShape: Qt.SizeFDiagCursor
            property point start
            property var origin
            onPressed: m => { start = mapToItem(null, m.x, m.y); origin = { x: frame.r.x, y: frame.r.y, w: frame.r.w, h: frame.r.h }; }
            onPositionChanged: m => {
                const p = mapToItem(null, m.x, m.y);
                frame.live = frame.fit({ x: origin.x, y: origin.y, w: origin.w + p.x - start.x, h: origin.h + p.y - start.y }, "resize");
            }
            onReleased: frame.commit()
        }
    }
    Rectangle {
        visible: frame.editing
        width: 22; height: 22; radius: 11
        anchors { right: parent.right; top: parent.top; margins: -8 }
        color: closeMouse.containsMouse ? Colors.danger : Materials.fill("overlay", 2)
        border.width: Tokens.hairline; border.color: Materials.border("overlay")
        Icon { anchors.centerIn: parent; name: "close"; size: 14; color: closeMouse.containsMouse ? "white" : Colors.text }
        MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: frame.removed() }
    }

    function commit() {
        if (!live) return;
        const r = live;
        moved({ x: r.x, y: r.y, w: r.w, h: r.h });
        // Keep the live rectangle until the saved one arrives, so it does not jump back.
        Qt.callLater(() => frame.live = null);
    }
}
