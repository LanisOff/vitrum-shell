import QtQuick
import qs.services
import qs.theme
import qs.components

// Charge as a ring, with the time left.
Item {
    id: root
    property var options: ({})
    readonly property real value: Power.hasBattery ? Power.percentage / 100 : 0
    WidgetHeader { id: head; icon: "battery"; title: "Battery"; hue: 100 }
    Label { anchors.centerIn: parent; visible: !Power.hasBattery; text: "No battery"; role: "dim" }
    Canvas {
        id: ring
        visible: Power.hasBattery
        width: Math.min(root.width, root.height - head.height - 4); height: width
        anchors.horizontalCenter: parent.horizontalCenter
        y: head.height + 4 + (root.height - head.height - 4 - height) / 2
        property real v: root.value
        property color track: Colors.alpha(Colors.text, 0.12)
        property color fill: Power.low ? Colors.danger : Colors.accent
        onVChanged: requestPaint()
        onFillChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"), r = width / 2 - 6;
            c.reset();
            c.lineWidth = 8; c.lineCap = "round";
            c.strokeStyle = track; c.beginPath(); c.arc(width / 2, height / 2, r, 0, 2 * Math.PI); c.stroke();
            c.strokeStyle = fill; c.beginPath(); c.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * v); c.stroke();
        }
        Column {
            anchors.centerIn: parent
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(Power.percentage) + "%"; numeric: true; size: Tokens.textLarge + 4 }
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: Power.charging ? "Charging" : Power.timeRemaining; role: "dim"; size: Tokens.textSmall }
        }
    }
}
