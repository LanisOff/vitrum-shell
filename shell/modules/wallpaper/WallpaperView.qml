import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.components
import "../../lib/wallpaper.js" as Lib

/*
 * The wallpaper drawn by the shell: when parallax is on (the image is a bit
 * taller than the screen and slides with the workspace), or when awww is not
 * installed. A change grows in as a circle from where it was asked (or the
 * centre), or fades, per wallpaper.transition.
 */
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property string path: Lib.pathFor(Wallpaper.conf, screen.name, Wallpaper.home)
    readonly property bool active: Wallpaper.shellDraws && path !== "" && !(Wallpaper.live && Lib.isVideo(path) && !!Wallpaper.installed.mpvpaper)

    visible: active
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "black"
    WlrLayershell.namespace: "vitrum-wallpaper"
    WlrLayershell.layer: WlrLayer.Background
    mask: Region {}                    // never takes input

    // Parallax: the image is `extra` taller; the active workspace's position picks the slice.
    readonly property real extra: Wallpaper.parallax ? height * 0.12 : 0
    readonly property var spaces: Niri.workspacesOn(screen.name)
    readonly property int index: Math.max(0, spaces.findIndex(w => w.active))
    readonly property real offset: Lib.parallaxOffset(index, spaces.length, extra)

    Item {
        id: canvas
        width: root.width
        height: root.height + root.extra
        y: root.offset
        Behavior on y { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }

        // The old picture stays under the new one until it has fully arrived.
        Image {
            id: under
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(root.width * 1.5, (root.height + root.extra) * 1.5)
        }
        Image {
            id: over
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: under.sourceSize
            visible: false
            onStatusChanged: if (status === Image.Ready) root.reveal()
        }
        MultiEffect {
            id: revealed
            anchors.fill: parent
            source: over
            maskEnabled: true
            maskSource: maskItem
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.2
        }
        Item {
            id: maskItem
            anchors.fill: parent
            layer.enabled: true
            visible: false
            Rectangle {
                id: circle
                property real r: 0
                width: 2 * r; height: 2 * r; radius: r
                x: grow.cx - r; y: grow.cy - r
                color: "white"
            }
        }
    }

    QtObject { id: grow; property real cx: root.width / 2; property real cy: root.height / 2 }

    onPathChanged: if (active) load()
    onActiveChanged: if (active) load()
    Component.onCompleted: if (active) load()

    function load() {
        const src = "file://" + path;
        if (under.source.toString() === src) return;
        if (!under.source.toString()) { under.source = src; return; }       // the first one: no transition
        const o = Wallpaper.origin && Wallpaper.origin.output === screen.name ? Wallpaper.origin : null;
        grow.cx = o ? o.x : width / 2;
        grow.cy = (o ? o.y : height / 2) - canvas.y;
        over.source = src;
    }
    function reveal() {
        const t = Motion.enabled ? Wallpaper.transition : "none";
        const far = Math.hypot(Math.max(grow.cx, width - grow.cx), Math.max(grow.cy, canvas.height - grow.cy));
        anim.stop();
        if (t === "none") { finish(); return; }
        circle.r = t === "grow" ? 0 : far;
        revealed.opacity = t === "fade" ? 0 : 1;
        anim.to = far;
        anim.start();
    }
    // The new picture moves underneath; the top one is dropped once that has loaded (no black frame).
    property bool swapping: false
    function finish() {
        swapping = true;
        under.source = over.source;
        if (under.status === Image.Ready) dropOver();
    }
    function dropOver() {
        swapping = false;
        over.source = "";
        circle.r = 0;
        revealed.opacity = 1;
    }
    Connections { target: under; function onStatusChanged() { if (root.swapping && under.status === Image.Ready) root.dropOver(); } }
    ParallelAnimation {
        id: anim
        property real to: 0
        NumberAnimation { target: circle; property: "r"; to: anim.to; duration: Wallpaper.transition === "grow" ? 900 : 0; easing.type: Easing.InOutCubic }
        NumberAnimation { target: revealed; property: "opacity"; to: 1; duration: Wallpaper.transition === "fade" ? 700 : 0; easing.type: Easing.InOutQuad }
        onFinished: Qt.callLater(root.finish)
    }
}
