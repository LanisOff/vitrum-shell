import QtQuick
import ".."
import qs.services
import qs.theme
StatusIcon {
    icon: "power"
    panel: ""
    onClicked: m => { if (m.button === Qt.LeftButton) UiState.toggle("power"); }
}
