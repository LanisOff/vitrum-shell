import QtQuick
import ".."
import qs.services
import qs.theme
import qs.components
import "../../../lib/timers.js" as Lib

// Activity: the computer powers off later. The countdown, or "after emerge"; a click cancels.
BarModule {
    id: root
    shown: Shutdown.pending
    implicitWidth: row.implicitWidth
    onClicked: Shutdown.cancel()
    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.gap / 2
        Icon { name: "power"; color: Colors.danger; anchors.verticalCenter: parent.verticalCenter }
        Label { text: Shutdown.afterEmerge ? "after " + Packages.toolName : Lib.format(Shutdown.secondsLeft); numeric: !Shutdown.afterEmerge; anchors.verticalCenter: parent.verticalCenter }
    }
}
