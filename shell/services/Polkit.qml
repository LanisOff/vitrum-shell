pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Polkit

/*
 * The polkit agent. The dialog (modules/dialogs/PolkitDialog.qml) shows
 * `flow` while `active` is true.
 */
Singleton {
    id: root
    readonly property bool registered: agent.isRegistered
    readonly property bool active: agent.isActive
    readonly property var flow: agent.flow

    PolkitAgent { id: agent }
}
