import QtQuick
import ".."
import qs.services
import qs.theme
import qs.components

// Activity: vitrum's repository has moved on (VitrumUpdate.threshold commits
// or more). Click: what is new, and Update.
BarModule {
    id: root
    shown: VitrumUpdate.due
    panel: "vitrum"
    implicitWidth: row.implicitWidth
    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.gap / 2
        Icon { name: "vitrum-update"; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
        Label { text: "vitrum"; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
        Label { text: "+" + VitrumUpdate.behind; role: "dim"; numeric: true; anchors.verticalCenter: parent.verticalCenter }
    }
}
