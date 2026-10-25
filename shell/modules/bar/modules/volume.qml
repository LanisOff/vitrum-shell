import QtQuick
import ".."
import qs.services
import qs.theme
StatusIcon {
    shown: Audio.available
    icon: Audio.muted || Audio.volume === 0 ? "volume-mute" : Audio.volume < 0.4 ? "volume-low" : "volume-high"
    tint: Audio.muted ? Colors.textDim : Colors.text
    // The level beside the icon (bar.modules.volume.percent); not while muted.
    label: Settings.get("bar.modules.volume.percent", false) && !Audio.muted ? Math.round(Audio.volume * 100) + "%" : ""
    onWheel: w => Audio.step(w.angleDelta.y > 0 ? 0.05 : -0.05)
    onClicked: m => { if (m.button === Qt.MiddleButton) Audio.toggleMute(); }
}
