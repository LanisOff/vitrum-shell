import QtQuick
import qs.services
import qs.theme
import qs.components
import "root:/lib/lock.js" as Lib

// Suspend, restart, power off. Suspend acts at once; restart and power off
// need a second press within three seconds — the first one says so, in a
// label that grows out of the button.
Row {
    id: power
    spacing: Tokens.gap
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
        model: [
            { action: "suspend",  icon: "sleep",   ask: "" },
            { action: "reboot",   icon: "restart", ask: "Press again to restart" },
            { action: "poweroff", icon: "power",   ask: "Press again to power off" },
        ]
        delegate: LockGlass {
            id: btn
            required property var modelData
            readonly property bool armed: power.pending !== null && power.pending.action === modelData.action
            backdrop: power.backdrop
            source: power.source
            height: Tokens.islandHeight * 1.3
            radius: height / 2
            width: height + (armed ? ask.implicitWidth + Tokens.padding * 1.5 : 0)
            clip: true
            tint: armed ? Colors.alpha(Colors.danger, 0.75) : m.pressed ? Colors.alpha(Colors.text, 0.22) : m.containsMouse ? Colors.alpha(Colors.text, 0.14) : Qt.rgba(1, 1, 1, Colors.dark ? 0.07 : 0.16)
            Behavior on width { enabled: Motion.enabled; SpringAnim { token: Motion.bouncy } }
            Behavior on tint { enabled: Motion.enabled; ColorAnim {} }
            scale: m.pressed ? 0.92 : 1
            Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: (btn.height - Tokens.iconSize) / 2
                spacing: Tokens.gap
                Icon { name: btn.modelData.icon; color: btn.armed ? "white" : Colors.text; anchors.verticalCenter: parent.verticalCenter }
                Label { id: ask; text: btn.modelData.ask; color: "white"; opacity: btn.armed ? 1 : 0; anchors.verticalCenter: parent.verticalCenter
                    Behavior on opacity { enabled: Motion.enabled; EaseAnim {} } }
            }
            MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: power.press(btn.modelData.action) }
        }
    }
}
