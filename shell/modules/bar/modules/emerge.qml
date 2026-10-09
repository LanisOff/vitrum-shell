import QtQuick
import ".."
import qs.services
import qs.theme
import qs.components
import "../../../lib/emerge.js" as Lib

// Activity: emerge is building, or pacman installing. How far (3/27) and how long to go.
BarModule {
    id: root
    shown: Packages.state.running
    panel: "updates"
    implicitWidth: row.implicitWidth
    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.gap / 2
        Icon { name: "build"; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter
               RotationAnimation on rotation { running: root.shown && Motion.enabled; loops: Animation.Infinite; from: -12; to: 12; duration: 900; easing.type: Easing.InOutSine } }
        Label { text: Packages.state.total ? Math.min(Packages.state.done + 1, Packages.state.total) + "/" + Packages.state.total : Packages.toolName; numeric: true; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
        Label { visible: text.length > 0; text: Lib.formatEta(Packages.secondsLeft); role: "dim"; size: Tokens.textSmall; anchors.verticalCenter: parent.verticalCenter }
    }
}
