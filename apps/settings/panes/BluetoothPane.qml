import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import qs.common

Page {
    title: "Bluetooth"
    subtitle: Bluetooth.present ? "" : "No Bluetooth adapter (or the bluetooth service is not running)."
    Section {
        visible: Bluetooth.present
        SettingRow {
            label: "Bluetooth"
            Toggle { checked: Bluetooth.powered; onToggled: Bluetooth.setPowered(!Bluetooth.powered) }
        }
        SettingRow {
            label: "Look for devices"; hint: Bluetooth.discovering ? "Searching…" : ""; divider: false
            Toggle { checked: Bluetooth.discovering; onToggled: Bluetooth.scan(!Bluetooth.discovering) }
        }
    }
    Section {
        title: "Devices"
        visible: Bluetooth.present && Bluetooth.powered
        Label { visible: Bluetooth.devices.length === 0; text: "No devices yet."; role: "dim"; padding: Tokens.padding }
        Repeater {
            model: Bluetooth.devices
            delegate: SettingRow {
                required property var modelData
                label: modelData.name || modelData.address || "?"
                hint: modelData.connected ? "Connected" + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "%" : "") : modelData.paired ? "Paired" : ""
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: Tokens.islandHeight * 1.05; radius: height / 2; width: bl.implicitWidth + Tokens.padding * 1.4
                    color: modelData.connected ? Colors.alpha(Colors.text, 0.06) : Colors.accent
                    Label { id: bl; anchors.centerIn: parent; text: modelData.connected ? "Disconnect" : "Connect"; role: modelData.connected ? "text" : "onAccent"; size: Tokens.textSmall + 1 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Bluetooth.toggle(modelData) }
                }
            }
        }
    }
}
