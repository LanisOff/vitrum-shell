import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth as BT
import qs.services
import qs.theme
import qs.components
import qs.common

// Your devices, and the ones around to pair. The search runs while this page
// is open; a pairing code, when there is one, comes up as a system dialog.
Page {
    id: page
    title: "Bluetooth"
    subtitle: Bluetooth.present ? "" : "No Bluetooth adapter (or the bluetooth service is not running)."
    Component.onCompleted: Bluetooth.scan(true)
    Component.onDestruction: Bluetooth.scan(false)
    Connections { target: Bluetooth; function onPoweredChanged() { if (Bluetooth.powered) Bluetooth.scan(true); } }

    Section {
        visible: Bluetooth.present
        SettingRow {
            label: "Bluetooth"
            hint: Bluetooth.powered && Bluetooth.adapter ? "This computer is “" + Bluetooth.adapter.name + "”" : ""
            Toggle { checked: Bluetooth.powered; onToggled: Bluetooth.setPowered(!Bluetooth.powered) }
        }
        SettingRow {
            visible: Bluetooth.powered
            label: "Visible to other devices"; hint: "While on, phones and computers nearby can find this one to pair."; divider: false
            Toggle { checked: Bluetooth.discoverable; onToggled: Bluetooth.setDiscoverable(!Bluetooth.discoverable) }
        }
    }
    Section {
        title: "My devices"
        visible: Bluetooth.present && Bluetooth.powered
        Label { visible: Bluetooth.paired.length === 0; text: "Nothing paired yet — pick a device below."; role: "dim"; padding: Tokens.padding }
        Repeater {
            model: Bluetooth.paired
            delegate: DeviceRow {
                required property var modelData
                required property int index
                device: modelData
                divider: index < Bluetooth.paired.length - 1
                hint: modelData.state === BT.BluetoothDeviceState.Connecting ? "Connecting…" : modelData.state === BT.BluetoothDeviceState.Disconnecting ? "Disconnecting…"
                    : modelData.connected ? "Connected" + (modelData.batteryAvailable ? " · battery " + Math.round(modelData.battery * 100) + "%" : "") : "Not connected"
                Icon {
                    name: "trash"; color: Colors.textDim; anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: forget.ask(modelData) }
                }
                Capsule { label: modelData.connected ? "Disconnect" : "Connect"; active: !modelData.connected; anchors.verticalCenter: parent.verticalCenter
                          onClicked: Bluetooth.toggle(modelData) }
            }
        }
    }
    Section {
        title: Bluetooth.discovering ? "Nearby · searching…" : "Nearby"
        visible: Bluetooth.present && Bluetooth.powered
        note: "To pair a device, put it in pairing mode (usually a long press on its power or Bluetooth button)."
        Label { visible: Bluetooth.nearby.length === 0; text: Bluetooth.discovering ? "Looking for devices…" : "No devices found."; role: "dim"; padding: Tokens.padding }
        Repeater {
            model: Bluetooth.nearby
            delegate: DeviceRow {
                required property var modelData
                required property int index
                device: modelData
                divider: index < Bluetooth.nearby.length - 1
                hint: modelData.pairing ? "Pairing…" : ""
                Capsule { label: modelData.pairing ? "Cancel" : "Pair"; active: !modelData.pairing; anchors.verticalCenter: parent.verticalCenter
                          onClicked: modelData.pairing ? modelData.cancelPair() : Bluetooth.pair(modelData) }
            }
        }
    }

    Sheet {
        id: forget
        property var device: null
        function ask(d) { device = d; open(); }
        title: "Forget “" + (device ? device.name : "") + "”?"
        subtitle: "It disconnects, and has to be paired again to come back."
        acceptText: "Forget"
        danger: true
        onAccepted: { Bluetooth.forget(device); close(); }
    }

    // A device: its icon, name, a line under it, and the controls.
    component DeviceRow: SettingRow {
        id: row
        property var device: null
        label: device ? (device.name || device.address) : ""
        leading: Quickshell.iconPath(device && device.icon ? device.icon : "bluetooth", "bluetooth")
    }
}
