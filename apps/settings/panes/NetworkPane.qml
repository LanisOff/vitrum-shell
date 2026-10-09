import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import qs.common

Page {
    title: "Network"
    subtitle: Network.nm ? "" : "NetworkManager is not running: the connection is shown from the system, and Wi-Fi is managed by whatever set it up."
    Section {
        title: "Connection"
        SettingRow {
            label: Network.online ? (Network.kind === "wifi" ? "Wi-Fi" : "Wired") : "Offline"
            hint: Network.online ? Network.name : "No connection"
            divider: false
            Icon { name: Network.kind === "wired" ? "ethernet" : Network.kind === "wifi" ? "wifi" : "network-off"; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    Section {
        title: "Wi-Fi"
        visible: Network.nm
        SettingRow {
            label: "Wi-Fi"
            Toggle { checked: Network.wifiEnabled; onToggled: Network.setWifiEnabled(!Network.wifiEnabled) }
        }
        Repeater {
            model: Network.wifiEnabled ? Network.wifiNetworks : []
            delegate: SettingRow {
                id: net
                required property var modelData
                label: modelData.name || modelData.ssid || "?"
                hint: modelData.connected ? "Connected" : ""
                Icon { name: "wifi"; opacity: 0.4 + 0.6 * (modelData.signalStrength || modelData.strength || 0); anchors.verticalCenter: parent.verticalCenter }
                MouseArea { parent: net; anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor; onClicked: if (!net.modelData.connected) Network.connect(net.modelData, "") }
            }
        }
    }
}
