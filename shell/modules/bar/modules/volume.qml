import QtQuick
import ".."
import qs.services
import qs.theme
StatusIcon {
    shown: Audio.available
    icon: Audio.muted || Audio.volume === 0 ? "volume-mute" : Audio.volume < 0.4 ? "volume-low" : "volume-high"
    tint: Audio.muted ? Colors.textDim : Colors.text
    onWheel: w => Audio.step(w.angleDelta.y > 0 ? 0.05 : -0.05)
    onClicked: m => { if (m.button === Qt.MiddleButton) Audio.toggleMute(); }
}
