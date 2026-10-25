import QtQuick
import QtQuick.Shapes
import qs.theme

// A circular gauge: a faint track, the value as an arc from the top with
// round ends that turns from `color` to `color2` along its length (dichroic:
// accent → accent2, or a meaning colour and its pair), and whatever is put
// inside it in the middle.
Item {
    id: root
    property real value: 0                    // 0..1
    property real thickness: Math.max(4, width * 0.1)
    property color color: Colors.accent
    property color color2: Colors.pair(color)
    property color trackColor: Colors.dark ? Qt.rgba(1, 1, 1, 0.08) : Colors.alpha(Colors.text, 0.10)
    default property alias content: inside.data
    implicitWidth: 64; implicitHeight: 64

    property real shown: Math.max(0, Math.min(1, value))
    Behavior on shown { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }

    readonly property real _cx: width / 2
    readonly property real _cy: height / 2
    readonly property real _rm: (Math.min(width, height) - thickness) / 2      // the arc's middle line
    readonly property real _ro: _rm + thickness / 2
    readonly property real _ri: Math.max(0, _rm - thickness / 2)
    readonly property real _sweep: Math.max(0.5, Math.min(360, 360 * shown))
    readonly property real _a0: -90
    readonly property real _a1: _a0 + _sweep
    // How far a round end reaches past the arc's ends, in degrees.
    readonly property real _cap: _rm > 0 ? (thickness / 2) / _rm * 180 / Math.PI : 0
    readonly property real _alpha: Colors.dark ? 0.9 : 1
    function _a(c) { return Qt.rgba(c.r, c.g, c.b, root._alpha); }
    function _px(a, r) { return root._cx + r * Math.cos(a * Math.PI / 180); }
    function _py(a, r) { return root._cy + r * Math.sin(a * Math.PI / 180); }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.trackColor; strokeWidth: root.thickness
            fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root._cx; centerY: root._cy
                radiusX: root._rm; radiusY: root._rm
                startAngle: 0; sweepAngle: 360
            }
        }
        // The value: a filled band (outer arc, round end, inner arc back,
        // round start) so a conical gradient can run along it. The gradient
        // turns counter-clockwise from its angle; the arc runs clockwise from
        // the top, so its start sits just under position 1 and its end lower.
        ShapePath {
            strokeColor: "transparent"; strokeWidth: 0
            fillRule: ShapePath.WindingFill
            fillGradient: ConicalGradient {
                centerX: root._cx; centerY: root._cy
                angle: 90 + root._cap
                GradientStop { position: 0; color: root._a(root.color2) }
                GradientStop { position: Math.max(0, 1 - (root._sweep + root._cap) / 360); color: root._a(root.color2) }
                GradientStop { position: Math.max(0, 1 - root._cap / 360); color: root._a(root.color) }
                GradientStop { position: 1; color: root._a(root.color) }
            }
            startX: root._px(root._a0, root._ro); startY: root._py(root._a0, root._ro)
            PathAngleArc {
                moveToStart: false
                centerX: root._cx; centerY: root._cy
                radiusX: root._ro; radiusY: root._ro
                startAngle: root._a0; sweepAngle: root._sweep
            }
            PathAngleArc {
                moveToStart: false
                centerX: root._px(root._a1, root._rm); centerY: root._py(root._a1, root._rm)
                radiusX: root.thickness / 2; radiusY: root.thickness / 2
                startAngle: root._a1; sweepAngle: 180
            }
            PathAngleArc {
                moveToStart: false
                centerX: root._cx; centerY: root._cy
                radiusX: root._ri; radiusY: root._ri
                startAngle: root._a1; sweepAngle: -root._sweep
            }
            PathAngleArc {
                moveToStart: false
                centerX: root._px(root._a0, root._rm); centerY: root._py(root._a0, root._rm)
                radiusX: root.thickness / 2; radiusY: root.thickness / 2
                startAngle: root._a0 + 180; sweepAngle: 180
            }
        }
    }
    Item { id: inside; anchors.fill: parent }
}
