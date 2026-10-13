import QtQuick
import qs.services
import qs.theme
import qs.components

/*
 * A clock face: twelve ticks (the quarters longer), numerals if asked, the
 * hour and minute hands in the text colour, the second hand in the chosen one.
 *   S   the face, filling the square
 *   L   the same face, larger, with the day and date in its lower half
 * options: seconds (second hand), numbers (1–12), color (the second hand's).
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "S"
    property bool preview: false
    signal optionsEdited(var options)

    readonly property bool seconds: options.seconds !== false
    readonly property bool numbers: options.numbers === true
    readonly property color handColor: !options.color || options.color === "accent" ? Colors.accent : Colors.ink(Number(options.color))

    property date now: new Date()
    // Without a second hand the minute hand moves a tenth of a degree a second: every 20 s is plenty.
    Timer {
        interval: root.seconds && !root.preview ? 1000 : 20000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    readonly property real secAngle: now.getSeconds() * 6
    readonly property real minAngle: now.getMinutes() * 6 + now.getSeconds() * 0.1
    readonly property real hourAngle: (now.getHours() % 12) * 30 + now.getMinutes() * 0.5

    // A hand: a rounded bar from a little behind the centre out to `length` (of the radius r).
    // Inline: it sees none of the file's ids, hence r passed in.
    component Hand: Item {
        id: hand
        property real length: 0.5
        property real thickness: 4
        property real tail: 0
        property color tint: Colors.text
        property real angle: 0
        property real r: 50
        anchors.fill: parent
        rotation: angle
        // The 59 → 0 step must go on clockwise, not swing back round.
        Behavior on rotation {
            enabled: Motion.enabled
            RotationAnimation { direction: RotationAnimation.Clockwise; duration: Motion.fast; easing.type: Easing.OutCubic }
        }
        Rectangle {
            width: hand.thickness
            height: hand.r * (hand.length + hand.tail)
            radius: width / 2
            x: (hand.width - width) / 2
            y: hand.r - hand.r * hand.length
            color: hand.tint
            antialiasing: true
        }
    }

    Item {
        id: face
        readonly property real d: Math.min(root.width, root.height)
        readonly property real r: d / 2
        width: d; height: d
        anchors.centerIn: parent

        // A faint dial, so the face reads as one object on the plate.
        Rectangle {
            anchors.fill: parent; radius: width / 2
            color: Colors.alpha(Colors.text, 0.04)
            border.width: Tokens.hairline; border.color: Colors.alpha(Colors.text, 0.10)
        }

        Repeater {
            model: 12
            delegate: Item {
                required property int index
                readonly property bool quarter: index % 3 === 0
                anchors.fill: parent
                rotation: index * 30
                Rectangle {
                    width: Math.max(2, face.d * (parent.quarter ? 0.024 : 0.014))
                    height: face.d * (parent.quarter ? (root.numbers ? 0.055 : 0.085) : (root.numbers ? 0.035 : 0.05))
                    radius: width / 2
                    x: (parent.width - width) / 2
                    y: face.d * 0.045
                    color: parent.quarter ? Colors.text : Colors.alpha(Colors.text, 0.45)
                }
            }
        }

        Repeater {
            model: root.numbers ? 12 : 0
            delegate: Label {
                required property int index
                readonly property real a: (index + 1) * Math.PI / 6
                readonly property real rr: face.r * 0.62
                text: String(index + 1)
                numeric: true
                size: Math.max(Tokens.textSmall, Math.round(face.d * 0.095))
                font.weight: (index + 1) % 3 === 0 ? Font.Medium : Font.Normal
                role: (index + 1) % 3 === 0 ? "text" : "dim"
                horizontalAlignment: Text.AlignHCenter
                width: size * 1.6; height: size * 1.2
                x: face.r + rr * Math.sin(a) - width / 2
                y: face.r - rr * Math.cos(a) - height / 2
            }
        }

        // The day and date, low on the face where the hands rarely rest for long.
        Label {
            visible: root.sizeClass !== "S"
            anchors.horizontalCenter: parent.horizontalCenter
            y: face.r + face.r * (root.numbers ? 0.30 : 0.36)
            text: Qt.formatDate(root.now, "ddd d")
            role: "dim"
            size: Math.max(Tokens.textSmall, Math.round(face.d * 0.05))
            font.weight: Font.Medium
            font.capitalization: Font.AllUppercase
        }

        Hand { r: face.r; length: 0.50; tail: 0.08; thickness: Math.max(3, face.d * 0.034); angle: root.hourAngle }
        Hand { r: face.r; length: 0.74; tail: 0.08; thickness: Math.max(2.5, face.d * 0.024); angle: root.minAngle }
        Hand { r: face.r; visible: root.seconds; length: 0.82; tail: 0.16; thickness: Math.max(1.5, face.d * 0.009); tint: root.handColor; angle: root.secAngle }

        Rectangle {
            width: Math.max(6, face.d * (root.seconds ? 0.05 : 0.06)); height: width; radius: width / 2
            anchors.centerIn: parent
            color: root.seconds ? root.handColor : Colors.text
        }
    }
}
