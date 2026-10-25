import QtQuick
import qs.theme

// A gauge in dichroic glass. Linear: a faint glass groove (radius
// Tokens.radiusMeter) filled to the value with the tint, from `color` to
// `color2`: no gap, no stop dot. Circular: Ring. An optional label above
// (left) and value (right). `color` unset is the accent → accent2 pair; a
// meaning colour (danger, warning, a tone) brings its own pair (Colors.pair).
Item {
    id: root
    property real value: 0                  // 0..1
    property string kind: "linear"          // linear | circular
    property string label: ""
    property string trailing: ""
    property color color: Colors.accent
    property color color2: Colors.pair(color)
    /// The material group it lies on: a meter over a game keeps its tint still.
    property string group: "panels"
    property real thickness: kind === "linear" ? 6 : Math.max(4, width * 0.11)
    readonly property real shown: Math.max(0, Math.min(1, value))
    implicitWidth: kind === "linear" ? 160 : 56
    implicitHeight: kind === "linear" ? (head.visible ? head.height + 6 : 0) + thickness : 56

    Item {
        id: head
        visible: root.kind === "linear" && (root.label.length > 0 || root.trailing.length > 0)
        width: root.width; height: Tokens.textSmall + 4
        Label { text: root.label; role: "dim"; size: Tokens.textSmall; width: parent.width * 0.6 }
        Label { anchors.right: parent.right; text: root.trailing; size: Tokens.textSmall; numeric: true; font.weight: Font.Medium }
    }
    Item {
        visible: root.kind === "linear"
        y: head.visible ? head.height + 6 : 0
        width: root.width; height: root.thickness
        readonly property real r: Math.min(Tokens.radiusMeter, height / 2)
        QtObject { id: anim; property real v: root.shown; Behavior on v { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } } }
        Rectangle {
            anchors.fill: parent
            radius: parent.r
            color: Colors.dark ? Qt.rgba(1, 1, 1, 0.07) : Colors.alpha(Colors.text, 0.07)
            border.width: 1
            border.color: Colors.dark ? Qt.rgba(1, 1, 1, 0.06) : Colors.alpha(Colors.text, 0.06)
        }
        ShellTint {
            visible: root.shown > 0
            width: Math.max(parent.height, parent.width * anim.v); height: parent.height
            radius: parent.r
            group: root.group
            tint: root.color
            color2: root.color2
            // Data: a touch more colour than a tinted control, in both schemes.
            alphaStart: Colors.dark ? 0.62 : 0.55
            alphaMiddle: Colors.dark ? 0.52 : 0.45
            alphaEnd: Colors.dark ? 0.60 : 0.52
        }
    }
    Ring {
        visible: root.kind === "circular"
        anchors.fill: parent
        value: root.shown
        thickness: root.thickness
        color: root.color
        color2: root.color2
        Label { anchors.centerIn: parent; text: root.trailing; numeric: true; font.weight: Font.Medium; size: Math.max(Tokens.textSmall, Math.round(root.width * 0.24)) }
    }
}
