import QtQuick
import qs.theme

/*
 * A button: an optional icon and label on glass, radius Tokens.radiusButton.
 * Secondary (default): the group's material (Surface), with a faint lift under
 * the pointer. Primary: the lit glass (Tint) on top, drifting under the
 * pointer, and the icon in the tint's colour. The text is Colors.text either
 * way. Pressed, it sinks a little
 * (a damped scale, no overshoot). Disabled (`enabled: false`), it dims and
 * stays still: no lift, no tint, no drift, no press. `labelSize` sets the
 * text's size (dense chips use Tokens.textSmall + 1).
 *
 *     GlassButton { icon: "save"; label: "Save"; primary: true; onClicked: … }
 */
Item {
    id: root
    property string icon: ""
    property string label: ""
    property bool primary: false
    /// A destructive action: the tint starts from Colors.danger.
    property bool danger: false
    property color tint: danger ? Colors.danger : Colors.accent
    property string group: "panels"
    property int level: 1
    property bool outlined: true
    property real radius: Tokens.radiusButton
    property int labelSize: Tokens.textSize
    readonly property bool hovered: enabled && mouse.containsMouse
    readonly property bool pressed: enabled && mouse.pressed
    signal clicked()

    implicitHeight: Tokens.islandHeight
    // An icon alone is a square key.
    implicitWidth: label.length === 0 ? implicitHeight : Math.max(implicitHeight, content.implicitWidth + 2 * Tokens.padding)

    opacity: enabled ? 1 : 0.45
    scale: root.pressed ? 0.97 : 1
    Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }

    Surface {
        anchors.fill: parent
        group: root.group
        level: root.level
        outlined: root.outlined
        radius: root.radius
    }
    // The lift under the pointer, on clear glass.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Colors.alpha(Colors.text, root.primary ? 0 : root.pressed ? 0.10 : root.hovered ? 0.06 : 0)
        Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
    }
    ShellTint {
        anchors.fill: parent
        radius: root.radius
        group: root.group
        tint: root.tint
        hovered: root.hovered
        active: root.primary && root.enabled
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Tokens.gap / 2
        Icon {
            visible: root.icon.length > 0; name: root.icon || "help"
            // Primary: the icon takes the tint's colour.
            color: root.primary && root.enabled ? root.tint : Colors.text
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { enabled: Motion.enabled; ColorAnim {} }
        }
        Label { visible: root.label.length > 0; text: root.label; size: root.labelSize; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
