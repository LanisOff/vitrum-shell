import QtQuick
import qs.theme

/*
 * When a layer-shell window that comes and goes is mapped.
 *
 *     MapGate { id: gate; want: root.open }
 *     visible: gate.mapped
 *
 * Quickshell deletes such a window on `visible: false` and builds a new one on
 * `true`, emitting geometry changes while it builds. A `visible` computed from
 * the window's geometry or an animation can flip in that moment and the window
 * is deleted under Quickshell (a segfault). So: mapping happens a tick after it
 * is wanted (never inside a window build), and unmapping waits out the exit
 * animation by time — `linger` — instead of watching coordinates.
 *
 * A full-screen overlay stays unmapped until it opens. Each mapped one holds its
 * own buffers in the shell and niri draws its background effect over the whole
 * surface, even with a 1 px region (BlurKick): with two screens the idle overlays
 * took 1.5 GB of video memory, and a full-screen blur on every frame of a game.
 */
QtObject {
    id: gate
    property bool want: false
    /// How long the exit animation may take; the window stays mapped that long.
    property int linger: Motion.enabled ? Motion.emphasized * 2 : 0
    property bool mapped: false
    /// True a tick after this object is built. A window made on demand
    /// (components/OnDemand.qml) has it in its `open`, so `open` still goes from
    /// false to true after the window exists: onOpenChanged runs and the
    /// entrance animates as for a window that was always there.
    property bool ready: false

    function _apply() {
        if (gate.want) { lingerTimer.stop(); gate.mapped = true; }
        else if (gate.mapped) lingerTimer.restart();
    }
    function _start() { gate.ready = true; Qt.callLater(gate._apply); }
    onWantChanged: Qt.callLater(gate._apply)
    Component.onCompleted: Qt.callLater(gate._start)

    property Timer lingerTimer: Timer {
        interval: Math.max(1, gate.linger)
        onTriggered: if (!gate.want) gate.mapped = false
    }
}
