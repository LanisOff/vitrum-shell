import QtQuick
import QtQuick.Shapes
import qs.theme

// A circular gauge: a faint track, the value as an arc from the top with a
// round cap, and whatever is put inside it in the middle.
Item {
    id: root
    property real value: 0                    // 0..1
    property real thickness: Math.max(4, width * 0.1)
    property color color: Colors.accent
    property color trackColor: Colors.alpha(Colors.text, 0.1)
    default property alias content: inside.data
    implicitWidth: 64; implicitHeight: 64

    property real shown: Math.max(0, Math.min(1, value))
    Behavior on shown { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.trackColor; strokeWidth: root.thickness
            fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: (root.width - root.thickness) / 2; radiusY: (root.height - root.thickness) / 2
                startAngle: 0; sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: root.color; strokeWidth: root.thickness
            fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: (root.width - root.thickness) / 2; radiusY: (root.height - root.thickness) / 2
                startAngle: -90; sweepAngle: Math.max(0.5, 360 * root.shown)
            }
        }
    }
    Item { id: inside; anchors.fill: parent }
}
