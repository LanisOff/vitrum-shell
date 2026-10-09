import QtQuick
import ".."
import qs.services
import qs.theme
// Shown only while a microphone exists; red while unmuted and in use is the honest signal.
StatusIcon {
    shown: Audio.source !== null
    icon: Audio.micMuted ? "mic-off" : "mic"
    tint: Audio.micMuted ? Colors.textDim : Colors.text
    onClicked: m => { if (m.button === Qt.MiddleButton) Audio.toggleMicMute(); }
}
