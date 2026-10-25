import QtQuick
import qs.theme
import qs.components

/*
 * A key as a glass cap: a raised face over its own thickness (a darker edge a
 * little below it), the name on the face. `size` is the text's size; the cap
 * grows with it. Used by the tour's text and by its illustrations.
 */
Item {
    id: root
    property string text: ""
    property int size: Tokens.textSmall
    property string group: "overlay"

    readonly property real depth: Math.max(Tokens.hairline * 2, Math.round(size / 6))
    implicitHeight: Math.round(size * 2.1) + depth
    implicitWidth: Math.max(implicitHeight - depth, cap.implicitWidth + Math.round(size * 1.3))

    // The cap's thickness, seen under its face.
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: root.depth
        radius: Tokens.radiusKnob
        color: Colors.dark ? Qt.rgba(0, 0, 0, 0.32) : Colors.alpha(Colors.text, 0.14)
    }
    Surface {
        width: parent.width
        height: parent.height - root.depth
        group: root.group
        level: 2
        radius: Tokens.radiusKnob
        border.color: Colors.alpha(Colors.text, 0.16)
        // The light along the top of the face.
        Rectangle {
            anchors { fill: parent; margins: Tokens.hairline }
            radius: Math.max(0, Tokens.radiusKnob - Tokens.hairline)
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, Colors.dark ? 0.10 : 0.45) }
                GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0) }
            }
        }
        Label {
            id: cap
            anchors.centerIn: parent
            text: root.text
            size: root.size
            font.weight: Font.DemiBold
        }
    }
}
