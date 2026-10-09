pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth as BT

/*
 * Bluetooth through Quickshell.Bluetooth (BlueZ over D-Bus).
 */
Singleton {
    id: root
    readonly property var adapter: BT.Bluetooth.defaultAdapter
    readonly property bool present: adapter !== null
    readonly property bool powered: present && adapter.enabled
    readonly property bool discovering: present && adapter.discovering
    readonly property var devices: present ? adapter.devices.values : []
    readonly property var connected: devices.filter(d => d.connected)

    function setPowered(on) { if (present) adapter.enabled = on; }
    function scan(on) { if (present) adapter.discovering = on; }
    function toggle(device) { device.connected ? device.disconnect() : device.connect(); }
}
