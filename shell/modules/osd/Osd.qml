import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.components

/*
 * On-screen display: a capsule at the top centre, under the bar, on the
 * focused screen. Volume, microphone, brightness, keyboard layout — shown
 * when the value changes, gone 1.2 s after the last change.
 */
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property bool here: screen.name === (Niri.focusedOutput || Quickshell.screens[0].name)

    property string kind: ""            // volume | mic | brightness | layout
    property bool showing: false
    function show(k) { if (!here) return; kind = k; showing = true; hide.restart(); }
    Timer { id: hide; interval: 1200; onTriggered: root.showing = false }

    // Changes after startup only (the first values are not news).
    property bool armed: false
    Timer { interval: 1500; running: true; onTriggered: root.armed = true }
    Connections { target: Audio; enabled: root.armed
        function onVolumeChanged() { root.show("volume"); }
        function onMutedChanged() { root.show("volume"); }
        function onMicMutedChanged() { root.show("mic"); } }
    Connections { target: Power; enabled: root.armed; function onBrightnessChanged() { root.show("brightness"); } }
    Connections { target: Niri; enabled: root.armed; function onKeyboardLayoutIndexChanged() { root.show("layout"); } }
    Connections { target: UiState; function onOsdRequested(k) { root.show(k); } }

    visible: true
    anchors { top: Settings.get("bar.position", "top") === "top"; bottom: Settings.get("bar.position", "top") !== "top" }
    margins { top: Tokens.islandHeight + 3 * Tokens.gap; bottom: Tokens.islandHeight + 3 * Tokens.gap }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: Tokens.islandHeight * 9
    implicitHeight: Tokens.islandHeight + 4
    color: "transparent"
    WlrLayershell.namespace: "vitrum-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region { item: dot }                  // never takes input
    BlurKick { id: blurKick; window: root }
    BackgroundEffect.blurRegion: Materials.wantsRegion("osd") && !blurKick.on ? effect : blurKick.none
    Region { id: effect; item: pill.opacity > 0.05 ? shape : dot; radius: pill.radius }
    Item { id: dot; width: 1; height: 1 }
    Item { id: shape; x: pill.x; y: pill.y; width: pill.width; height: pill.height }

    readonly property real value: kind === "volume" ? Audio.volume : kind === "mic" ? Audio.micVolume
                                  : kind === "brightness" ? Power.brightness : 0
    readonly property string iconName: kind === "volume" ? (Audio.muted ? "volume-mute" : Audio.volume < 0.4 ? "volume-low" : "volume-high")
                                     : kind === "mic" ? (Audio.micMuted ? "mic-off" : "mic")
                                     : kind === "brightness" ? "brightness" : "keyboard"

    Surface {
        id: pill
        group: "osd"
        width: parent.width
        height: Tokens.islandHeight
        radius: height / 2
        y: root.showing ? 2 : -height
        opacity: root.showing ? 1 : 0
        Behavior on y { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }

        Row {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding; anchors.rightMargin: Tokens.padding
            spacing: Tokens.gap
            Icon { name: root.iconName; anchors.verticalCenter: parent.verticalCenter; color: Colors.accent }
            Item {
                visible: root.kind !== "layout"
                width: parent.width - Tokens.iconSize * 4.5 - 2 * Tokens.gap
                height: 6; anchors.verticalCenter: parent.verticalCenter
                Rectangle { anchors.fill: parent; radius: 3; color: Colors.alpha(Colors.text, 0.15) }
                Rectangle {
                    height: parent.height; radius: 3; color: Colors.accent
                    width: parent.width * Math.max(0, Math.min(1, root.value))
                    Behavior on width { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
                }
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                numeric: true
                text: root.kind === "layout" ? Niri.keyboardLayout
                    : (root.kind === "volume" && Audio.muted) || (root.kind === "mic" && Audio.micMuted) ? "muted"
                    : Math.round(root.value * 100) + "%"
            }
        }
    }
}
