import QtQuick
import qs.services
import qs.theme
import qs.components

// An icon and a tabular figure — the system island's building block.
BarModule {
    id: root
    property string icon: "cpu"
    property string value: ""
    property bool alert: false
    panel: "resources"
    implicitWidth: row.implicitWidth
    Component.onCompleted: SysInfo.subscribe()
    Component.onDestruction: SysInfo.unsubscribe()
    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.gap / 2
        Icon { name: root.icon; size: Tokens.iconSize * 0.9; color: root.alert ? Colors.danger : Colors.textDim; anchors.verticalCenter: parent.verticalCenter }
        Label { text: root.value; numeric: true; role: root.alert ? "danger" : "text"; anchors.verticalCenter: parent.verticalCenter }
    }
}
