import QtQuick
import QtQuick.Shapes
import qs.theme

/*
 * The vitrum mark: a V cut from glass like a gem, the same six facets as
 * assets/vitrum-mark.svg (README, boot splash, fastfetch), drawn here in the
 * accent pair — the left arm in the accent, the right in accent2 — with the
 * white glass edges and a light from the top. The SVG itself is not installed
 * with the apps, and its fixed blue would not follow the wallpaper.
 */
Item {
    id: gem
    property color color: Colors.accent
    property color color2: Colors.accent2
    implicitWidth: 64
    implicitHeight: 64

    // The SVG's 256 box, scaled to fit.
    readonly property real k: Math.min(width, height) / 256

    component Facet: ShapePath {
        id: f
        property var pts: []
        property color from: "white"
        property color to: "white"
        property bool flip: false
        strokeColor: "transparent"
        strokeWidth: 0
        fillGradient: LinearGradient {
            x1: f.flip ? 256 : 0; y1: 0; x2: f.flip ? 0 : 256; y2: 256
            GradientStop { position: 0; color: f.from }
            GradientStop { position: 1; color: f.to }
        }
        startX: f.pts[0]; startY: f.pts[1]
        PathPolyline { path: [Qt.point(f.pts[0], f.pts[1]), Qt.point(f.pts[2], f.pts[3]), Qt.point(f.pts[4], f.pts[5]), Qt.point(f.pts[6], f.pts[7]), Qt.point(f.pts[0], f.pts[1])] }
    }
    component Edge: ShapePath {
        id: e
        property var pts: []
        property real alpha: 0.5
        fillColor: "transparent"
        strokeColor: Qt.rgba(1, 1, 1, e.alpha)
        joinStyle: ShapePath.RoundJoin
        capStyle: ShapePath.RoundCap
        startX: e.pts[0]; startY: e.pts[1]
        PathPolyline { path: e.pts.length >= 6 ? [Qt.point(e.pts[0], e.pts[1]), Qt.point(e.pts[2], e.pts[3]), Qt.point(e.pts[4], e.pts[5])]
                                               : [Qt.point(e.pts[0], e.pts[1]), Qt.point(e.pts[2], e.pts[3])] }
    }

    Shape {
        width: 256; height: 256
        anchors.centerIn: parent
        scale: gem.k
        preferredRendererType: Shape.CurveRenderer

        // Left arm: two outer facets split at a ridge, then the inner face,
        // each a step deeper (a pale accent would wash out if lightened).
        Facet { pts: [28, 48, 56, 48, 128, 196, 128, 224]; from: gem.color; to: Qt.darker(gem.color, 1.15) }
        Facet { pts: [56, 48, 82, 48, 128, 150, 128, 196]; from: Qt.darker(gem.color, 1.2); to: Qt.darker(gem.color, 1.65) }
        Facet { pts: [82, 48, 108, 48, 128, 96, 128, 150]; from: Qt.darker(gem.color, 1.7); to: Qt.darker(gem.color, 2.6) }
        // Right arm.
        Facet { pts: [228, 48, 200, 48, 128, 196, 128, 224]; flip: true; from: gem.color2; to: Qt.darker(gem.color2, 1.15) }
        Facet { pts: [200, 48, 174, 48, 128, 150, 128, 196]; flip: true; from: Qt.darker(gem.color2, 1.2); to: Qt.darker(gem.color2, 1.65) }
        Facet { pts: [174, 48, 148, 48, 128, 96, 128, 150]; flip: true; from: Qt.darker(gem.color2, 1.7); to: Qt.darker(gem.color2, 2.6) }

        // The light from above, on the whole V: brighter at the top edge.
        ShapePath {
            strokeColor: "transparent"
            strokeWidth: 0
            fillGradient: LinearGradient {
                x1: 0; y1: 48; x2: 0; y2: 224
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.26) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.03) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
            }
            startX: 28; startY: 48
            PathPolyline { path: [Qt.point(28, 48), Qt.point(108, 48), Qt.point(128, 96), Qt.point(148, 48), Qt.point(228, 48), Qt.point(128, 224), Qt.point(28, 48)] }
        }

        // The glass edges.
        Edge { pts: [28, 48, 128, 224, 228, 48]; alpha: 0.8; strokeWidth: 2 }
        Edge { pts: [56, 48, 128, 196, 200, 48]; alpha: 0.35; strokeWidth: 1.2 }
        Edge { pts: [82, 48, 128, 150, 174, 48]; alpha: 0.35; strokeWidth: 1.2 }
        Edge { pts: [108, 48, 128, 96, 148, 48]; alpha: 0.5; strokeWidth: 1.5 }
        Edge { pts: [28, 48, 108, 48]; alpha: 0.85; strokeWidth: 2.5 }
        Edge { pts: [148, 48, 228, 48]; alpha: 0.85; strokeWidth: 2.5 }
    }
}
