import QtQuick
import qs.theme

/*
 * An on/off switch: a 38×22 glass track (at compact density; it scales with
 * the island) with radius Tokens.radiusSwitch, and a glass bead with radius
 * Tokens.radiusKnob that slides across on a damped spring. Off, the track is
 * the group's material; on, it is lit glass (Tint) with a faint wash of the
 * tint's colour in it (α .14 in dark).
 * Not named Switch: QtQuick.Controls has one.
 */
Item {
    id: root
    property bool checked: false
    property color tint: Colors.accent
    property string group: "panels"
    readonly property bool pressed: press.pressed
    signal toggled()

    readonly property real _u: Tokens.islandHeight / 30
    implicitWidth: Math.round(38 * _u)
    implicitHeight: Math.round(22 * _u)

    Surface {
        anchors.fill: parent
        group: root.group
        level: 2
        outlined: true
        radius: Tokens.radiusSwitch
    }
    ShellTint {
        anchors.fill: parent
        radius: Tokens.radiusSwitch
        group: root.group
        tint: root.tint
        color2: root.tint
        active: root.checked
        // On, lit glass with a faint wash of the colour in it (no light under
        // the small track).
        alphaStart: 0
        alphaMiddle: Colors.dark ? 0.14 : 0.16
        alphaEnd: alphaMiddle
    }
    Item {
        id: bead
        readonly property real inset: Math.round(3 * root._u)
        height: root.height - 2 * inset
        // Stretched while held, like a finger pressing on it.
        width: height + (press.pressed ? Math.round(height * 0.3) : 0)
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - inset : inset
        Behavior on x { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }
        Behavior on width { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
        // Its shadow, a pixel under it.
        Rectangle {
            anchors.fill: parent; anchors.topMargin: 1; anchors.bottomMargin: -1
            radius: Tokens.radiusKnob
            color: Qt.rgba(0, 0, 0, Colors.dark ? 0.30 : 0.14)
        }
        Rectangle {
            anchors.fill: parent
            radius: Tokens.radiusKnob
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, Colors.dark ? 0.88 : 1) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, Colors.dark ? 0.40 : 0.82) }
            }
            border.width: Colors.dark ? 0 : 1
            border.color: Colors.alpha(Colors.text, 0.12)
        }
    }
    MouseArea { id: press; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled() }
}
