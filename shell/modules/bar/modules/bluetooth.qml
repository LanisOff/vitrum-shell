import QtQuick
import ".."
import qs.services
import qs.theme
StatusIcon {
    shown: Bluetooth.present
    icon: !Bluetooth.powered ? "bluetooth-off" : Bluetooth.connected.length > 0 ? "bluetooth-connected" : "bluetooth"
    tint: Bluetooth.powered ? Colors.text : Colors.textDim
    label: Bluetooth.connected.length > 1 ? String(Bluetooth.connected.length) : ""
}
