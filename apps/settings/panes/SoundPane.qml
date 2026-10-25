import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import qs.common

Page {
    title: "Sound"
    // The volume sound plays from here as well, while the slider moves.
    Component.onCompleted: Sounds.inShell
    subtitle: Audio.available ? "" : "No PipeWire audio here."
    Section {
        title: "Output"
        visible: Audio.available
        SettingRow {
            label: "Volume"; hint: Audio.sinkName
            GlassSwitch { checked: !Audio.muted; onToggled: Audio.toggleMute() }
            // The wheel scrolls the page (it would change the volume under a passing pointer).
            Slider { width: Tokens.islandHeight * 8; value: Audio.volume; icon: Audio.muted ? "volume-mute" : "volume-high"; wheel: false; onMoved: v => Audio.setVolume(v) }
        }
        Repeater {
            model: Audio.sinks
            delegate: DeviceRow { required property var modelData; node: modelData; current: Audio.sink; onPicked: Audio.setDefaultSink(modelData) }
        }
    }
    Section {
        title: "Input"
        visible: Audio.sources.length > 0
        SettingRow {
            label: "Microphone"; hint: Audio.sourceName
            GlassSwitch { checked: !Audio.micMuted; onToggled: Audio.toggleMicMute() }
            Slider { width: Tokens.islandHeight * 8; value: Audio.micVolume; icon: Audio.micMuted ? "mic-off" : "mic"; wheel: false; onMoved: v => Audio.setMicVolume(v) }
        }
        Repeater {
            model: Audio.sources
            delegate: DeviceRow { required property var modelData; node: modelData; current: Audio.source; onPicked: Audio.setDefaultSource(modelData) }
        }
    }
    Section {
        title: "Microphone filter"
        SettingToggle { key: "audio.noiseFilter"; label: "Remove background noise"; hint: NoiseFilter.available ? "RNNoise between the microphone and every app: a new default microphone, “Noise-free microphone”. Off puts your microphone back."
                                                                                           : "Needs RNNoise (noise-suppression-for-voice), which is not installed."
                      divider: false }
    }
    Section {
        title: "System sounds"
        SettingToggle { key: "sounds.screenshot"; label: "Screenshots" }
        SettingToggle { key: "sounds.volume"; label: "Volume changes" }
        SettingToggle { key: "sounds.lock"; label: "Lock and unlock" }
        SettingToggle { key: "sounds.device"; label: "Devices plugged in or out" }
        // Only heard on a laptop (Sounds plays it with a battery).
        SettingToggle { key: "sounds.power"; label: "Charger plugged in or out"; visible: Power.hasBattery }
        SettingText { key: "sounds.theme"; label: "Sound theme folder"; placeholder: "/usr/share/sounds/freedesktop/stereo"; fieldWidth: Tokens.islandHeight * 12; divider: false }
    }
    component DeviceRow: SettingRow {
        id: dr
        property var node: null
        property var current: null      // the default node
        signal picked()
        readonly property string title: node ? (node.description || node.nickname || node.name || "") : ""
        label: title
        Icon { name: "check"; visible: !!dr.node && dr.node === dr.current; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
        // The whole row picks it (the default slot is only the control on the right).
        MouseArea { parent: dr; anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor; onClicked: dr.picked() }
    }
}
