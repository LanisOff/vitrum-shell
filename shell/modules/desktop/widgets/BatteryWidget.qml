import QtQuick
import qs.services
import qs.theme
import qs.components

/*
 * The laptop's charge (Power, from UPower).
 *   S   the charge as a ring, the percentage inside (a bolt over it while it
 *       charges), how long it lasts under it
 *   M   the header with the state; the percentage big, the time beside it;
 *       the charge as a bar along the bottom
 * options: time (how long until empty, or until full while charging).
 * In a gallery card on a machine with no battery, a sample 76 % stands in.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    readonly property bool sample: preview && !Power.hasBattery
    readonly property bool ready: Power.hasBattery || sample
    readonly property real pct: sample ? 76 : Power.percentage
    readonly property bool charging: !sample && Power.charging
    readonly property bool low: !sample && Power.low
    readonly property string timeLeft: sample ? "4:12" : Power.timeRemaining
    readonly property color tint: low ? Colors.danger : Colors.accent
    readonly property bool showTime: options.time !== false

    // "4:12 left", "Full in 0:40"; without a time, the state.
    readonly property string timeText: {
        if (showTime && timeLeft) return charging ? "Full in " + timeLeft : timeLeft + " left";
        if (charging) return "Charging";
        if (!sample && Power.pluggedIn) return "Plugged in";
        return "On battery";
    }

    // A lightning bolt (a line icon, like the rest), sized by its width.
    component Bolt: Icon { name: "bolt"; size: Math.max(8, width) }

    WidgetHeader {
        id: head
        visible: root.sizeClass !== "S"
        height: visible ? implicitHeight : 0
        icon: "battery"; title: "Battery"
        tint: root.tint
        trailing: !root.ready ? "" : root.charging ? "Charging" : root.sample || !Power.pluggedIn ? "On battery" : "Plugged in"
    }
    WidgetEmpty {
        visible: !root.ready
        icon: "battery"
        text: "No battery"
    }

    // ---- S: the ring.
    Column {
        visible: root.ready && root.sizeClass === "S"
        anchors.centerIn: parent
        spacing: Tokens.gap * 0.4
        readonly property real d: Math.max(48, Math.min(root.width, root.height - Tokens.textSmall - Tokens.gap * 0.4 - 4) * 0.92)
        Meter {
            id: ring
            group: "widgets"
            anchors.horizontalCenter: parent.horizontalCenter
            kind: "circular"
            width: parent.d; height: parent.d
            thickness: Math.max(6, width * 0.085)
            value: root.pct / 100
            color: root.tint
            Column {
                anchors.centerIn: parent
                spacing: 0
                Bolt {
                    visible: root.charging
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.round(ring.width * 0.16); height: width
                    color: root.tint
                }
                Metric {
                    anchors.horizontalCenter: parent.horizontalCenter
                    value: String(Math.round(root.pct))
                    unit: "%"
                    size: Math.round(ring.width * (root.charging ? 0.26 : 0.3))
                }
            }
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, root.width)
            horizontalAlignment: Text.AlignHCenter
            text: root.timeText
            role: "dim"; size: Tokens.textSmall; numeric: true
        }
    }

    // ---- M: the number, the time, the bar.
    Item {
        visible: root.ready && root.sizeClass !== "S"
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; topMargin: Tokens.gap * 0.6 }
        Row {
            anchors { left: parent.left; bottom: bar.top; bottomMargin: Tokens.gap * 0.6 }
            spacing: Tokens.gap
            Metric {
                id: big
                value: String(Math.round(root.pct))
                unit: "%"
                size: Math.max(24, Math.min(52, (bar.y - Tokens.gap * 0.6) * 0.8))
            }
            Bolt {
                visible: root.charging
                width: Math.round(big.size * 0.5); height: width
                y: big.height - height - big.size * 0.18
                color: root.tint
            }
        }
        Label {
            anchors { right: parent.right; bottom: bar.top; bottomMargin: Tokens.gap * 0.6 + 4 }
            width: Math.min(implicitWidth, parent.width * 0.5)
            horizontalAlignment: Text.AlignRight
            text: root.timeText
            role: "dim"; numeric: true
        }
        Meter {
            id: bar
            group: "widgets"
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            kind: "linear"
            thickness: 8
            value: root.pct / 100
            color: root.tint
        }
    }
}
