import QtQuick
import ".."
import qs.services
import qs.theme
import qs.components
import "../../../lib/timers.js" as Lib

// Activity: a timer or a pomodoro runs. The nearest one counts down; click for all of them.
BarModule {
    id: root
    shown: Timers.list.length > 0
    panel: "timers"
    implicitWidth: row.implicitWidth
    readonly property var t: Timers.next
    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.gap / 2
        Icon { name: root.t && root.t.kind === "pomodoro" ? "hourglass" : "timer"; color: root.t && root.t.paused ? Colors.textDim : Colors.accent; anchors.verticalCenter: parent.verticalCenter }
        Label { text: root.t ? Lib.format(Timers.leftOf(root.t)) : ""; numeric: true; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
        Label { visible: Timers.list.length > 1; text: "+" + (Timers.list.length - 1); role: "dim"; size: Tokens.textSmall; anchors.verticalCenter: parent.verticalCenter }
    }
}
