import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.components

// The delay before a capture: a number in the middle of the focused screen.
// It is gone before the shot is taken (Capture waits a moment after zero).
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property bool shown: Capture.countdown > 0 && !!modelData && modelData.name === (Niri.focusedOutput || Quickshell.screens[0].name)

    MapGate { id: gate; want: root.shown }      // mapped only while counting (components/MapGate.qml)
    visible: gate.mapped
    implicitWidth: Tokens.islandHeight * 4
    implicitHeight: Tokens.islandHeight * 4
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "vitrum-capture-countdown"
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region { item: root.shown ? disc : dot }   // Escape is not ours to take; a click on it cancels
    BlurKick { id: blurKick; window: root }
    BackgroundEffect.blurRegion: Materials.wantsRegion("overlay") && !blurKick.on ? effect : blurKick.none
    Region { id: effect; item: gate.mapped ? disc : dot; radius: gate.mapped ? disc.radius : 0 }
    Item { id: dot; width: 1; height: 1 }

    Surface {
        id: disc
        group: "overlay"
        anchors.centerIn: parent
        width: parent.width; height: width; radius: width / 2
        opacity: root.shown ? 1 : 0
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
        Label {
            id: num
            anchors.centerIn: parent
            text: Capture.countdown
            numeric: true
            size: Tokens.textTitle * 2.4
            font.weight: Font.Light
            // Each second pops in.
            scale: 1
            onTextChanged: if (Motion.enabled) pop.restart()
            SequentialAnimation { id: pop; NumberAnimation { target: num; property: "scale"; to: 1.25; duration: 0 } SpringAnimation { target: num; property: "scale"; to: 1; spring: 4; damping: 0.35 } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Capture.cancelCountdown() }
    }
}
