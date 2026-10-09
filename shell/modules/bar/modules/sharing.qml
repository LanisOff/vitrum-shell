import QtQuick
import ".."
import qs.services
import qs.theme
import qs.components
import "../../../lib/text.js" as TextLib

// Activity: the screen is being shared. Who it goes to; click for details and stop.
BarModule {
    id: root
    shown: Privacy.shares.length > 0
    panel: "privacy"
    implicitWidth: row.implicitWidth
    readonly property string app: Privacy.shares.length ? (Apps.forAppId(Privacy.shares[0].app) || {}).name || Privacy.shares[0].app || "An app" : ""

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.gap / 2
        Icon { name: "screen-share"; color: "#bf5af2"; filled: true; anchors.verticalCenter: parent.verticalCenter }
        Label { text: TextLib.elide(root.app, 18); anchors.verticalCenter: parent.verticalCenter }
    }
}
