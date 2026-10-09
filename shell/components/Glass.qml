import QtQuick
import QtQuick.Effects

/*
 * Liquid glass drawn by the scene itself (glass.frag), for the screens niri
 * puts nothing under: the lock and the login. The children are the glass's
 * body — any shape: a rounded rectangle, the digits of a clock — and the
 * backdrop item is what shows through it, bent at the rim, a touch brighter
 * and more saturated, lit from the top left. niri's own glass (the bar, the
 * panels) does the same for real windows.
 *
 * Plain QtQuick only: the SDDM theme uses this file as it is.
 *
 *   backdrop   the item drawn behind (for where the glass sits over it)
 *   source     a texture of it (a ShaderEffectSource), shared by every piece
 *              of glass over the same backdrop; made here when not given
 *   bevel      how far in from the edge the glass curves, in pixels
 */
Item {
    id: root
    property Item backdrop: null
    property Item source: null
    default property alias body: shape.data

    property real bevel: 16
    property real refraction: 22
    property real fringing: 0.25
    property real edgeLight: 0.55
    property real saturation: 1.15
    property real brightness: 0.03
    property color tint: Qt.rgba(1, 1, 1, 0.06)
    /// 0..1: a soft shadow under the body, so thin glass reads on a busy picture.
    property real shadow: 0

    readonly property real pad: Math.ceil(bevel * 1.5)

    // The body, with room around it for the blur to fall off.
    Item {
        id: box
        x: -root.pad; y: -root.pad
        width: root.width + 2 * root.pad
        height: root.height + 2 * root.pad
        visible: false
        Item { id: shape; x: root.pad; y: root.pad; width: root.width; height: root.height }
    }
    // The height map: the body, blurred.
    MultiEffect {
        id: heightFx
        anchors.fill: box
        source: box
        visible: false
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: Math.max(1, Math.min(64, Math.round(root.bevel)))
    }
    MultiEffect {
        anchors.fill: box
        visible: root.shadow > 0
        source: box
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: Math.max(1, Math.min(64, Math.round(root.bevel * 1.5)))
        colorization: 1
        colorizationColor: "black"
        opacity: root.shadow
        transform: Translate { y: root.bevel * 0.35 }
    }
    ShaderEffectSource { id: bodySrc; sourceItem: box; visible: false }
    ShaderEffectSource { id: heightSrc; sourceItem: heightFx; visible: false }
    ShaderEffectSource { id: ownSrc; sourceItem: root.source ? null : root.backdrop; visible: false; hideSource: false }

    ShaderEffect {
        id: fx
        anchors.fill: box
        visible: !!root.backdrop
        property var backdrop: root.source || ownSrc
        property var body: bodySrc
        property var heightMap: heightSrc
        property rect bgRect: Qt.rect(0, 0, 1, 1)
        property point px: Qt.point(1 / Math.max(1, width), 1 / Math.max(1, height))
        property real refraction: root.refraction
        property real fringing: root.fringing
        property real edgeLight: root.edgeLight
        property real saturation: root.saturation
        property real brightness: root.brightness
        // Premultiplied for the shader.
        property vector4d tint: Qt.vector4d(root.tint.r * root.tint.a, root.tint.g * root.tint.a, root.tint.b * root.tint.a, root.tint.a)
        fragmentShader: Qt.resolvedUrl("glass.frag.qsb")
    }

    // Where the glass is over the backdrop, followed on every frame the window
    // draws anyway: it rides on transforms (rising in, shaking) no binding
    // would see. A still screen draws no frames, and costs nothing.
    function _sync() {
        const b = root.backdrop;
        if (!b || b.width <= 0 || b.height <= 0) return;
        const p = fx.mapToItem(b, 0, 0), q = fx.mapToItem(b, fx.width, fx.height);
        const r = Qt.rect(p.x / b.width, p.y / b.height, (q.x - p.x) / b.width, (q.y - p.y) / b.height);
        const o = fx.bgRect;
        if (Math.abs(r.x - o.x) + Math.abs(r.y - o.y) + Math.abs(r.width - o.width) + Math.abs(r.height - o.height) > 1e-6) fx.bgRect = r;
    }
    Connections {
        target: root.visible && root.backdrop ? root.Window.window : null
        function onAfterAnimating() { root._sync(); }
    }
    Component.onCompleted: _sync()
    // A backdrop given after creation (a Loader's onLoaded), or a window that
    // animates nothing (the desktop): afterAnimating may not come for a while.
    onBackdropChanged: Qt.callLater(_sync)
    onWidthChanged: Qt.callLater(_sync)
    onHeightChanged: Qt.callLater(_sync)
}
