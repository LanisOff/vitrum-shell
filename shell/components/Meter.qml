import QtQuick
import qs.theme

// A Material 3 progress indicator. Linear: a rounded bar, a small gap where it
// ends, the rest of the track, and a stop dot at the far end. Circular: Ring.
// An optional label above (left) and value (right).
Item {
    id: root
    property real value: 0                  // 0..1
    property string kind: "linear"          // linear | circular
    property string label: ""
    property string trailing: ""
    property color color: Colors.accent
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
        property real fillW: Math.max(root.thickness, (width - 4) * anim.v)
        QtObject { id: anim; property real v: root.shown; Behavior on v { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } } }
        Rectangle { width: parent.fillW; height: parent.height; radius: height / 2; color: root.color; visible: root.shown > 0 }
        Rectangle {
            x: root.shown > 0 ? parent.fillW + 4 : 0
            width: Math.max(0, parent.width - x); height: parent.height; radius: height / 2
            color: Colors.alpha(root.color, 0.22)
        }
        Rectangle {
            visible: root.shown < 0.97
            width: parent.height * 0.66; height: width; radius: width / 2
            anchors { right: parent.right; rightMargin: (parent.height - width) / 2; verticalCenter: parent.verticalCenter }
            color: root.color
        }
    }
    Ring {
        visible: root.kind === "circular"
        anchors.fill: parent
        value: root.shown
        thickness: root.thickness
        color: root.color
        trackColor: Colors.alpha(root.color, 0.2)
        Label { anchors.centerIn: parent; text: root.trailing; numeric: true; font.weight: Font.Medium; size: Math.max(Tokens.textSmall, Math.round(root.width * 0.24)) }
    }
}
