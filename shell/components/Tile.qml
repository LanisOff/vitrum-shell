import QtQuick
import qs.theme

/*
 * A Control Centre tile: icon, title, subtitle, and a chevron when it has a
 * submenu (a click on the chevron's end expands, anywhere else toggles).
 * A radius-12 piece in the group's material; on, the lit glass (Tint) lies on
 * top, its light drifting under the pointer, and the icon takes the tint's
 * colour. The title stays Colors.text, the subtitle dim: no fill swap, no
 * "on accent" text.
 */
Item {
    id: root
    property string icon: "help"
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool hasMenu: false
    property color tint: Colors.accent
    property string group: "panels"
    property int level: 1
    property bool outlined: true
    property real radius: Tokens.radiusTile
    readonly property bool hovered: mouse.containsMouse
    signal toggled()
    signal expand()

    implicitHeight: Math.round(Tokens.islandHeight * 1.6)
    implicitWidth: Tokens.islandHeight * 5

    scale: mouse.pressed ? 0.97 : 1
    Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }

    Surface {
        anchors.fill: parent
        group: root.group
        level: root.level
        outlined: root.outlined
        radius: root.radius
    }
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Colors.alpha(Colors.text, !root.active && mouse.containsMouse ? 0.06 : 0)
        Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
    }
    ShellTint {
        anchors.fill: parent
        radius: root.radius
        group: root.group
        tint: root.tint
        hovered: mouse.containsMouse
        active: root.active
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding
        anchors.rightMargin: Tokens.padding
        spacing: Tokens.gap
        // On, the icon takes the tint's colour: the glass stays clear, the colour is a light.
        Icon {
            name: root.icon
            color: root.active ? root.tint : Colors.text
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { enabled: Motion.enabled; ColorAnim {} }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Tokens.iconSize * 2 - Tokens.gap * 2
            Label { width: parent.width; text: root.title; font.weight: Font.DemiBold }
            Label { width: parent.width; visible: text.length > 0; text: root.subtitle; size: Tokens.textSmall; role: "dim" }
        }
        Icon { visible: root.hasMenu; name: "chevron"; color: Colors.textDim; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: m => (root.hasMenu && m.x > width - Tokens.iconSize * 2) ? root.expand() : root.toggled()
    }
}
