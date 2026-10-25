import QtQuick
import QtQuick.Shapes

/*
 * Lit glass: the look of anything that is on. The glass itself turns lighter
 * and frostier (a white wash, brighter at the top), with a brighter inner 1px
 * rim and a light along the top edge; the colour is only a soft light just
 * under the piece and around its lower edge, as if it lit the panel beneath.
 * Data fills (a meter, a forecast bar) can carry colour in the glass too
 * (alphaMiddle, alphaEnd), so a warning still reads red.
 *
 * Motion: `drift` (0..1; `hovered` runs it in about 1.2 s, damped, no
 * overshoot) slides the light under the piece toward the far side and makes
 * it a little stronger. When `active` turns true the piece fades in and a
 * soft light passes across the frosted surface once (about 1 s, damped;
 * sweep() runs it by hand), then rests. `active` false fades it out. At rest
 * nothing moves and nothing is redrawn; with `animate` false nothing moves at
 * all.
 *
 * Plain QtQuick + QtQuick.Shapes: the lock and the SDDM theme use this file
 * as it is. In the shell use ShellTint, which binds the theme (accent,
 * accent2, the scheme, Motion.enabled, game mode). Off pieces are not drawn
 * here: they keep their material (Surface), and this goes on top of it.
 * The light under the piece draws a little outside its bounds (mostly
 * below), so a parent that clips tightly cuts it.
 *
 *   radius       corners (clamped to half the size)
 *   color        the light's colour (the accent); its lightness is capped
 *                so a pastel accent still reads as colour over grey glass
 *   color2       the second hue (accent2), for colour in the glass
 *   dark         the scheme: in the light one white on a pale panel would
 *                vanish, so the wash is stronger, the rim takes the light's
 *                colour, the light is deeper and also rises faintly inside
 *                the glass from its bottom edge
 *   active       shown (it owns its opacity: fades in with a sweep, fades out)
 *   hovered      slide the light toward the far side while true
 *   animate      false: no drift, no sweep, no fade (reduced motion, a game)
 *   rim          the rim and the top light; false on very small pieces
 *   alphaStart   strength of the coloured light under the piece
 *   alphaMiddle  colour in the glass on the left (`color`), 0 for controls
 *   alphaEnd     colour in the glass on the right (`color2`), 0 for controls
 */
Item {
    id: root
    property real radius: 0
    property color color: "#8ab4f8"
    property color color2: "#e7a6f2"
    property bool dark: true
    property bool active: true
    property bool hovered: false
    property bool animate: true
    property int duration: 1200
    property int sweepDuration: 1000
    property int fadeDuration: 380
    property real drift: animate && hovered ? 1 : 0
    /// The rim and the top light; false on very small pieces.
    property bool rim: true

    property real alphaStart: dark ? 0.65 : 0.45
    property real alphaMiddle: 0
    property real alphaEnd: 0
    // In the light scheme white on a light panel would vanish: the rim takes
    // the light's colour instead.
    property color rimColor: dark ? Qt.rgba(1, 1, 1, 0.30) : _a(_glow, 0.55)
    property color lightColor: Qt.rgba(1, 1, 1, dark ? 0.55 : 1)

    Behavior on drift {
        enabled: root.animate
        NumberAnimation { duration: root.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] }
    }

    opacity: active ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { enabled: root.animate; NumberAnimation { duration: root.fadeDuration; easing.type: Easing.OutCubic } }

    /// One pass of light across the frosted surface, from the near side to the far one.
    function sweep() { if (root.animate && root.width > 0) sweepAnim.restart(); }
    onActiveChanged: { if (active) sweep(); else sweepAnim.stop(); }
    onAnimateChanged: { if (!animate) { sweepAnim.stop(); _sweep = 0; } }
    /// The pass: 1 when it starts (the light off the near side), 0 when done.
    property real _sweep: 0
    NumberAnimation {
        id: sweepAnim
        target: root; property: "_sweep"; from: 1; to: 0
        duration: root.sweepDuration
        easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1]
        onStopped: root._sweep = 0
    }

    readonly property real _r: Math.max(0, Math.min(radius, width / 2, height / 2))
    /// Where the light under the piece is: 0 home (centred), 1 at the far side.
    readonly property real _pos: drift
    readonly property bool _sweeping: _sweep > 0 && _sweep < 1

    function _a(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    /// The light's colour: the hue of `color`, its lightness capped (pastel
    /// accents wash to beige or lilac over grey glass) and its saturation kept up.
    function _deep(c) {
        const l = Math.min(c.hslLightness, dark ? 0.62 : 0.55);
        const s = c.hslSaturation < 0.08 ? c.hslSaturation : Math.max(c.hslSaturation, 0.6);
        return Qt.hsla(Math.max(0, c.hslHue), s, l, 1);
    }
    readonly property color _glow: _deep(color)

    // The frosted wash, top and bottom. Colour in the glass takes the place
    // of part of it (a switch's track, a meter), so the colour stays clear.
    readonly property real _frostKeep: 1 - Math.min(1, 1.4 * Math.max(alphaMiddle, alphaEnd))
    readonly property real _frostTop: (dark ? 0.20 : 0.55) * _frostKeep
    readonly property real _frostBottom: (dark ? 0.10 : 0.30) * _frostKeep
    // The light seen through the glass from below: none in dark (the light
    // under the piece reads on its own there); in light it is what tells an
    // on piece from the pale off ones.
    readonly property real _wash: (dark ? 0 : 0.22) * _frostKeep
    readonly property real _passAlpha: dark ? 0.16 : 0.55

    // The light under the piece: a blurred, shrunken copy of the piece moved
    // down (CSS: 0 4px 16px −6px), drawn only outside it. It is a radial
    // gradient squashed to an ellipse round the piece, the piece cut out.
    // Its reach scales down on small pieces (a 6 px meter gets a hint).
    readonly property real _gs: Math.max(0.3, Math.min(1, height / 36))
    readonly property real _gx: 12 * _gs                         // reach past the sides
    readonly property real _gb: 18 * _gs                         // past the bottom
    readonly property real _gdy: 4 * _gs                         // the drop
    readonly property real _gcx: width / 2 + width * 0.16 * _pos // the drift moves it
    readonly property real _gcy: height / 2 + _gdy
    readonly property real _grx: width / 2 + _gx
    readonly property real _gry: height / 2 - _gdy + _gb
    // The drawn box: the ellipse at rest plus room for the drift, so the
    // gradient always ends inside it (no cut edge) and the path never changes.
    readonly property real _gm: _gx + width * 0.16
    readonly property real _gt: _gb - 2 * _gdy
    readonly property real _gk: _gry / Math.max(1, _grx)          // item y = shape y × k
    // Where the piece's bottom edge is on the gradient (0 centre … 1 its end).
    readonly property real _ge: Math.max(0.05, Math.min(0.9, (height / 2 - _gdy) / Math.max(1, _gry)))
    readonly property real _gA: alphaStart * (1 + 0.25 * _pos)

    // The light under the piece.
    Shape {
        visible: root.width > 0 && root.height > 0 && root.alphaStart > 0
        x: -root._gm; y: -root._gt
        width: root.width + 2 * root._gm
        height: (root.height + root._gt + root._gb) / root._gk
        transform: Scale { yScale: root._gk }
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            id: reach
            readonly property real k: root._gk
            readonly property real l: root._gm
            readonly property real t: root._gt / k
            readonly property real w: root.width
            readonly property real h: root.height / k
            readonly property real rx: root._r
            readonly property real ry: root._r / k
            strokeColor: "transparent"
            strokeWidth: 0
            fillRule: ShapePath.OddEvenFill
            fillGradient: RadialGradient {
                centerX: root._gcx + root._gm; centerY: (root._gcy + root._gt) / root._gk
                centerRadius: root._grx
                focalX: centerX; focalY: centerY
                GradientStop { position: 0; color: root._a(root._glow, root._gA * 0.6) }
                GradientStop { position: root._ge; color: root._a(root._glow, root._gA * 0.6) }
                GradientStop { position: root._ge + (1 - root._ge) * 0.3; color: root._a(root._glow, root._gA * 0.3) }
                GradientStop { position: root._ge + (1 - root._ge) * 0.65; color: root._a(root._glow, root._gA * 0.1) }
                GradientStop { position: 1; color: root._a(root._glow, 0) }
            }
            // The whole reach…
            startX: 0; startY: 0
            PathLine { x: root.width + 2 * root._gm; y: 0 }
            PathLine { x: root.width + 2 * root._gm; y: (root.height + root._gt + root._gb) / root._gk }
            PathLine { x: 0; y: (root.height + root._gt + root._gb) / root._gk }
            PathLine { x: 0; y: 0 }
            // …less the piece.
            PathMove { x: reach.l + reach.rx; y: reach.t }
            PathLine { x: reach.l + reach.w - reach.rx; y: reach.t }
            PathArc { x: reach.l + reach.w; y: reach.t + reach.ry; radiusX: reach.rx; radiusY: reach.ry }
            PathLine { x: reach.l + reach.w; y: reach.t + reach.h - reach.ry }
            PathArc { x: reach.l + reach.w - reach.rx; y: reach.t + reach.h; radiusX: reach.rx; radiusY: reach.ry }
            PathLine { x: reach.l + reach.rx; y: reach.t + reach.h }
            PathArc { x: reach.l; y: reach.t + reach.h - reach.ry; radiusX: reach.rx; radiusY: reach.ry }
            PathLine { x: reach.l; y: reach.t + reach.ry }
            PathArc { x: reach.l + reach.rx; y: reach.t; radiusX: reach.rx; radiusY: reach.ry }
        }
    }

    Shape {
        anchors.fill: parent
        visible: root.width > 0 && root.height > 0
        preferredRendererType: Shape.CurveRenderer

        // Colour in the glass: only data fills and a switch's track ask for it.
        ShapePath {
            strokeColor: "transparent"
            strokeWidth: 0
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: root.width; y2: 0
                GradientStop { position: 0; color: root._a(root.color, root.alphaMiddle) }
                GradientStop { position: 1; color: root._a(root.color2, root.alphaEnd) }
            }
            startX: root._r; startY: 0
            PathLine { x: root.width - root._r; y: 0 }
            PathArc { x: root.width; y: root._r; radiusX: root._r; radiusY: root._r }
            PathLine { x: root.width; y: root.height - root._r }
            PathArc { x: root.width - root._r; y: root.height; radiusX: root._r; radiusY: root._r }
            PathLine { x: root._r; y: root.height }
            PathArc { x: 0; y: root.height - root._r; radiusX: root._r; radiusY: root._r }
            PathLine { x: 0; y: root._r }
            PathArc { x: root._r; y: 0; radiusX: root._r; radiusY: root._r }
        }
        // The light through the glass, rising from the bottom edge.
        ShapePath {
            strokeColor: "transparent"
            strokeWidth: 0
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: root.height
                GradientStop { position: 0.35; color: root._a(root._glow, 0) }
                GradientStop { position: 1; color: root._a(root._glow, root._wash) }
            }
            startX: root._r; startY: 0
            PathLine { x: root.width - root._r; y: 0 }
            PathArc { x: root.width; y: root._r; radiusX: root._r; radiusY: root._r }
            PathLine { x: root.width; y: root.height - root._r }
            PathArc { x: root.width - root._r; y: root.height; radiusX: root._r; radiusY: root._r }
            PathLine { x: root._r; y: root.height }
            PathArc { x: 0; y: root.height - root._r; radiusX: root._r; radiusY: root._r }
            PathLine { x: 0; y: root._r }
            PathArc { x: root._r; y: 0; radiusX: root._r; radiusY: root._r }
        }
        // The frost: the glass lighter, brighter at the top.
        ShapePath {
            strokeColor: "transparent"
            strokeWidth: 0
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: root.height
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, root._frostTop) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, root._frostBottom) }
            }
            startX: root._r; startY: 0
            PathLine { x: root.width - root._r; y: 0 }
            PathArc { x: root.width; y: root._r; radiusX: root._r; radiusY: root._r }
            PathLine { x: root.width; y: root.height - root._r }
            PathArc { x: root.width - root._r; y: root.height; radiusX: root._r; radiusY: root._r }
            PathLine { x: root._r; y: root.height }
            PathArc { x: 0; y: root.height - root._r; radiusX: root._r; radiusY: root._r }
            PathLine { x: 0; y: root._r }
            PathArc { x: root._r; y: 0; radiusX: root._r; radiusY: root._r }
        }
        // The light on the top edge: the band between the outline and itself
        // moved down a pixel, 1px at the top and thinning to nothing round the
        // corners, as light catches a glass edge.
        ShapePath {
            strokeColor: "transparent"
            strokeWidth: 0
            fillColor: root.rim ? root.lightColor : "transparent"
            startX: 0; startY: root._r
            PathArc { x: root._r; y: 0; radiusX: root._r; radiusY: root._r }
            PathLine { x: root.width - root._r; y: 0 }
            PathArc { x: root.width; y: root._r; radiusX: root._r; radiusY: root._r }
            PathLine { x: root.width; y: root._r + 1 }
            PathArc { x: root.width - root._r; y: 1; radiusX: root._r; radiusY: root._r; direction: PathArc.Counterclockwise }
            PathLine { x: root._r; y: 1 }
            PathArc { x: 0; y: root._r + 1; radiusX: root._r; radiusY: root._r; direction: PathArc.Counterclockwise }
            PathLine { x: 0; y: root._r }
        }
    }
    // The pass of light on switching on: a soft slanted band that crosses the
    // frost once. Only drawn while it runs.
    Shape {
        id: pass
        anchors.fill: parent
        visible: root._sweeping && root.width > 0 && root.height > 0
        preferredRendererType: Shape.CurveRenderer
        readonly property real band: Math.max(root.height, root.width * 0.3)
        readonly property real p: -band + (root.width + 2 * band) * (1 - root._sweep)
        ShapePath {
            strokeColor: "transparent"
            strokeWidth: 0
            fillGradient: LinearGradient {
                x1: pass.p - pass.band / 2; y1: 0
                x2: pass.p + pass.band / 2; y2: root.height * 0.7
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, root._passAlpha) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
            }
            startX: root._r; startY: 0
            PathLine { x: root.width - root._r; y: 0 }
            PathArc { x: root.width; y: root._r; radiusX: root._r; radiusY: root._r }
            PathLine { x: root.width; y: root.height - root._r }
            PathArc { x: root.width - root._r; y: root.height; radiusX: root._r; radiusY: root._r }
            PathLine { x: root._r; y: root.height }
            PathArc { x: 0; y: root.height - root._r; radiusX: root._r; radiusY: root._r }
            PathLine { x: 0; y: root._r }
            PathArc { x: root._r; y: 0; radiusX: root._r; radiusY: root._r }
        }
    }
    // The inner rim.
    Rectangle {
        anchors.fill: parent
        visible: root.rim && root.width > 0
        radius: root._r
        color: "transparent"
        border.width: 1
        border.color: root.rimColor
    }
}
