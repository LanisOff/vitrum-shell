import QtQuick
import qs.theme

/*
 * A slider 0..1 with an icon; drag, click or scroll. A glass groove (inset
 * from the item's top and bottom) in the group's material, a rounded rect
 * and never a stadium (its radius is about a third of its height, at most
 * Tokens.radiusSwitch), filled to the value with lit glass (Tint); the icon
 * sits on the left, in Colors.text. At low values the fill shrinks to a
 * sliver of its own rounded ends, never a dot. `wheel` false lets
 * the scroll wheel pass through (a slider in a scrolling page).
 */
Item {
    id: root
    property real value: 0
    property string icon: "volume-high"
    property color tint: Colors.accent
    property string group: "panels"
    /// The scroll wheel moves the value; false hands it on to what is under.
    property bool wheel: true
    signal moved(real value)

    implicitHeight: Tokens.islandHeight
    implicitWidth: 200
    readonly property real inset: Math.round(4 * Tokens.islandHeight / 30)
    readonly property real radius: Math.min(Tokens.radiusSwitch, Math.round(track.height * 0.36))

    Surface {
        id: track
        anchors { fill: parent; topMargin: root.inset; bottomMargin: root.inset }
        group: root.group
        level: 1
        outlined: true
        radius: root.radius
    }
    ShellTint {
        anchors { left: parent.left; top: track.top; bottom: track.bottom }
        // Never narrower than its own rounded ends.
        width: Math.max(2 * root.radius, root.width * Math.max(0, Math.min(1, root.value)))
        radius: root.radius
        group: root.group
        tint: root.tint
        Behavior on width { enabled: Motion.enabled && !drag.pressed; SpringAnim { token: Motion.snappy } }
    }
    Icon { id: glyph; visible: root.icon.length > 0; name: root.icon || "help"; x: root.inset; anchors.verticalCenter: parent.verticalCenter; color: Colors.text }
    MouseArea {
        id: drag
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function _set(x) { const v = Math.max(0, Math.min(1, x / width)); root.moved(v); }
        onPressed: m => _set(m.x)
        onPositionChanged: m => { if (pressed) _set(m.x); }
        onWheel: w => {
            if (!root.wheel) { w.accepted = false; return; }
            root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))));
        }
    }
}
