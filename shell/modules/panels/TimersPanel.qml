import QtQuick
import qs.services
import qs.theme
import qs.components
import "../../lib/timers.js" as Lib

// Every running timer: its time left, pause and stop. A pomodoro shows its round.
Column {
    id: root
    spacing: Tokens.gap
    width: Tokens.islandHeight * 10
    Repeater {
        model: Timers.list
        Card {
            required property var modelData
            width: root.width
            Row {
                spacing: Tokens.gap
                width: root.width - 2 * Tokens.padding
                Column {
                    width: parent.width - pause.width - stop.width - 2 * Tokens.gap
                    anchors.verticalCenter: parent.verticalCenter
                    Label { text: Lib.format(Timers.leftOf(modelData)); size: Tokens.textTitle; numeric: true; font.weight: Font.DemiBold }
                    Label { text: modelData.kind === "pomodoro" ? modelData.label + " · round " + modelData.round : modelData.label; role: "dim" }
                }
                Capsule { id: pause; icon: modelData.paused ? "play" : "pause"; anchors.verticalCenter: parent.verticalCenter; onClicked: Timers.togglePause(modelData.id) }
                Capsule { id: stop; icon: "close"; anchors.verticalCenter: parent.verticalCenter; onClicked: Timers.cancel(modelData.id) }
            }
        }
    }
    Label { visible: Timers.list.length === 0; text: "No timers. Type 5m or pomodoro in the launcher."; role: "dim" }
}
