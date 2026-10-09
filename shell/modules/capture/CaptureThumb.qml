import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components

/*
 * The last capture, floating in the bottom-right corner of the focused
 * screen for capture.thumbnailSeconds (hovering keeps it).
 *
 * Click: edit (satty, or the default app). Drag: drop the file into any app.
 * Buttons on hover: copy, show in folder, dismiss.
 */
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property bool focused_: !!modelData && modelData.name === (Niri.focusedOutput || Quickshell.screens[0].name)
    property var shot: null
    property bool shown: false
    readonly property bool isVideo: shot !== null && shot.kind === "video"

    Connections {
        target: Capture
        function onLastChanged() {
            if (!Capture.last || !root.focused_) return;
            root.shot = Capture.last;
            root.shown = true;
            life.restart();
        }
    }
    Timer { id: life; interval: Settings.get("capture.thumbnailSeconds", 6) * 1000; onTriggered: if (!hover.hovered) root.shown = false; else restart() }

    // Mapped only while shown or sliding out (see Centre.qml).
    // Mapped while shown and for the slide out (see components/MapGate.qml).
    MapGate { id: gate; want: root.shown }
    visible: gate.mapped
    anchors { bottom: true; right: true }
    implicitWidth: Tokens.islandHeight * 10 + 2 * Tokens.gap
    implicitHeight: Tokens.islandHeight * 7 + 2 * Tokens.gap
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "vitrum-capture-thumb"
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region { item: root.shown ? card : dot }
    BlurKick { id: blurKick; window: root }
    BackgroundEffect.blurRegion: Materials.wantsRegion("overlay") && !blurKick.on ? effect : blurKick.none
    Region { id: effect; item: gate.mapped ? card : dot; radius: gate.mapped ? card.radius : 0 }
    Item { id: dot; width: 1; height: 1 }

    Surface {
        id: card
        group: "overlay"
        width: parent.width - 2 * Tokens.gap
        height: parent.height - 2 * Tokens.gap
        y: Tokens.gap
        // Slides in from the right edge; out the same way.
        x: root.shown ? Tokens.gap : root.width + 4
        Behavior on x { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }
        clip: true

        HoverHandler { id: hover; onHoveredChanged: if (!hovered) life.restart() }

        Item {
            id: picture
            anchors.fill: parent
            anchors.margins: Tokens.padding * 0.75

            Image {
                id: img
                anchors.fill: parent
                visible: !root.isVideo
                source: root.shot && !root.isVideo ? "file://" + root.shot.path : ""
                sourceSize.width: 600
                fillMode: Image.PreserveAspectFit
                cache: false
                asynchronous: true
            }
            Column {
                anchors.centerIn: parent
                visible: root.isVideo
                spacing: Tokens.gap
                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "video"; size: Tokens.iconSize * 3 }
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: root.shot ? root.shot.path.split("/").pop() : ""; role: "dim"; size: Tokens.textSmall }
            }

            // Drag the file out; a plain click edits it.
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.mimeData: root.shot ? { "text/uri-list": "file://" + root.shot.path + "\r\n" } : ({})
            Drag.active: dragger.active
            DragHandler { id: dragger; target: null }
            TapHandler { onTapped: { if (root.shot) Capture.edit(root.shot.path); root.shown = false; } }
        }

        // Hover actions.
        Row {
            anchors { right: parent.right; top: parent.top; margins: Tokens.gap }
            spacing: Tokens.gap / 2
            opacity: hover.hovered ? 1 : 0
            Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
            Repeater {
                model: [
                    { icon: "copy",   show: !root.isVideo, run: () => Capture.copy(root.shot.path) },
                    { icon: "folder", show: true,          run: () => Capture.showInFolder(root.shot.path) },
                    { icon: "close",  show: true,          run: () => {} }
                ]
                delegate: Surface {
                    required property var modelData
                    visible: modelData.show
                    group: "overlay"; level: 2; outlined: false
                    width: Tokens.islandHeight; height: width; radius: width / 2
                    Icon { anchors.centerIn: parent; name: modelData.icon; size: Tokens.iconSize * 0.9 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.shot) modelData.run(); root.shown = false; } }
                }
            }
        }
    }
}
