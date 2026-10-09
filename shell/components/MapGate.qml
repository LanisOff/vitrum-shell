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
 */
QtObject {
    id: gate
    property bool want: false
    /// How long the exit animation may take; the window stays mapped that long.
    property int linger: Motion.enabled ? Motion.emphasized * 2 : 0
    property bool mapped: false

    function _apply() {
        if (gate.want) { lingerTimer.stop(); gate.mapped = true; }
        else if (gate.mapped) lingerTimer.restart();
    }
    onWantChanged: Qt.callLater(gate._apply)
    Component.onCompleted: Qt.callLater(gate._apply)

    property Timer lingerTimer: Timer {
        interval: Math.max(1, gate.linger)
        onTriggered: if (!gate.want) gate.mapped = false
    }
}
