import QtQuick
import ".."
import qs.services
import qs.theme
// Visible while the screen is being recorded; click stops it.
StatusIcon {
    shown: UiState.recording
    icon: "recording"
    tint: Colors.danger
    filled: true
    panel: ""
    onClicked: UiState.stopRecording()
}
