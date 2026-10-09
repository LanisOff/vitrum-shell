import QtQuick
import qs.theme

// A capsule slider 0..1 with an icon; drag, click or scroll.
Item {
    id: root
    property real value: 0
    property string icon: "volume-high"
    signal moved(real value)

    implicitHeight: Tokens.islandHeight
    implicitWidth: 200

    Surface { id: track; anchors.fill: parent; group: "panels"; level: 1; outlined: false; radius: height / 2 }
    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: Math.max(height, parent.width * root.value)
        radius: height / 2
        color: Colors.accent
        Behavior on width { enabled: Motion.enabled && !drag.pressed; SpringAnim { token: Motion.snappy } }
    }
    Icon { name: root.icon; x: (parent.height - width) / 2; anchors.verticalCenter: parent.verticalCenter; color: Colors.onAccent }
    MouseArea {
        id: drag
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function _set(x) { const v = Math.max(0, Math.min(1, x / width)); root.moved(v); }
        onPressed: m => _set(m.x)
        onPositionChanged: m => { if (pressed) _set(m.x); }
        onWheel: w => root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
