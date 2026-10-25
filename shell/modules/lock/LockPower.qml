import QtQuick
import qs.services
import qs.theme
import qs.components
import "root:/lib/lock.js" as Lib

// Sleep, restart, power off: square glass tiles (Tokens.radiusTile) with a
// line icon each. Under the pointer a tile lifts and its name grows out of it.
// Sleep acts at once; restart and power off need a second press within three
// seconds: the first one arms the tile — the danger tint fades in and sweeps
// across once, and a short label says to press again.
Row {
    id: power
    spacing: Tokens.gap
    layoutDirection: Qt.RightToLeft    // anchored at the right: names grow leftwards
    property var pending: null
    property Item backdrop: null
    property Item source: null
    readonly property int window: 3000

    function press(action) {
        const r = Lib.powerPress(pending, action, Date.now(), window);
        pending = r.pending;
        if (pending) disarm.restart();
        if (r.fire === "suspend") Power.suspend();
        else if (r.fire === "reboot") Power.reboot();
        else if (r.fire === "poweroff") Power.shutdown();
    }
    Timer { id: disarm; interval: power.window; onTriggered: power.pending = null }

    Repeater {
        // Right to left: power off sits in the corner.
        model: [
            { action: "poweroff", icon: "power" },
            { action: "reboot",   icon: "restart" },
            { action: "suspend",  icon: "sleep" },
        ]
        delegate: LockGlass {
            id: btn
            required property var modelData
            readonly property bool armed: power.pending !== null && power.pending.action === modelData.action
            readonly property bool open: armed || m.containsMouse
            backdrop: power.backdrop
            source: power.source
            height: Tokens.islandHeight * 1.4
            radius: Tokens.radiusTile
            width: height + (open ? label.implicitWidth + Tokens.padding : 0)
            clip: true
            tint: m.pressed ? Colors.alpha(Colors.text, 0.20) : m.containsMouse ? Colors.alpha(Colors.text, 0.13) : Qt.rgba(1, 1, 1, Colors.dark ? 0.07 : 0.16)
            edgeLight: m.containsMouse ? 0.75 : 0.5
            Behavior on width { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }
            Behavior on tint { enabled: Motion.enabled; ColorAnim {} }
            Behavior on edgeLight { enabled: Motion.enabled; EaseAnim {} }
            scale: m.pressed ? 0.97 : 1
            Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
            // Armed: Colors.danger and its pair.
            ShellTint {
                anchors.fill: parent
                radius: btn.radius
                group: "lock"
                tint: Colors.danger
                active: btn.armed
                hovered: m.containsMouse
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: (btn.height - Tokens.iconSize) / 2
                spacing: Tokens.gap
                Icon { name: btn.modelData.icon; size: Tokens.iconSize; anchors.verticalCenter: parent.verticalCenter }
                Label {
                    id: label
                    text: Lib.powerLabel(btn.modelData.action, btn.armed)
                    font.weight: btn.armed ? Font.DemiBold : Font.Medium
                    opacity: btn.open ? 1 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on opacity { enabled: Motion.enabled; EaseAnim {} }
                }
            }
            MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: power.press(btn.modelData.action) }
        }
    }
}
