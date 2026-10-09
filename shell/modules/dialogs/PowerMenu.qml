import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components

// Lock, log out, suspend, restart, power off — now or later.
DialogFrame {
    id: root
    open: UiState.power && screen.name === (Niri.focusedOutput || Quickshell.screens[0].name)
    onDismissed: UiState.power = false

    function act(f) { UiState.power = false; f(); }

    Column {
    spacing: Tokens.gap * 2
    Row {
        spacing: Tokens.gap * 1.5
        Repeater {
            model: [
                { icon: "lock",    label: "Lock",      run: () => UiState.locked = true },
                { icon: "logout",  label: "Log out",   run: () => Power.logout() },
                { icon: "sleep",   label: "Suspend",   run: () => Power.suspend() },
                { icon: "restart", label: "Restart",   run: () => Power.reboot() },
                { icon: "power",   label: "Power off", run: () => Power.shutdown() }
            ]
            delegate: Column {
                required property var modelData
                spacing: Tokens.gap
                Surface {
                    width: Tokens.islandHeight * 2.6; height: width; radius: width / 2
                    group: "dialogs"; level: 1; outlined: false
                    color: mouse.containsMouse ? Colors.accent : Materials.fill("dialogs", 1)
                    Icon { anchors.centerIn: parent; name: modelData.icon; size: Tokens.iconSize * 1.8; color: mouse.containsMouse ? Colors.onAccent : Colors.text }
                    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.act(modelData.run) }
                }
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; role: "dim" }
            }
        }
    }
    // Power off later.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Tokens.gap / 2
        Label { text: "Power off"; role: "dim"; anchors.verticalCenter: parent.verticalCenter; rightPadding: Tokens.gap / 2 }
        Capsule { icon: "timer"; label: "in 30 min"; onClicked: root.act(() => Shutdown.inMinutes(30)) }
        Capsule { icon: "timer"; label: "in 1 h"; onClicked: root.act(() => Shutdown.inMinutes(60)) }
        Capsule { visible: Packages.state.running; icon: "build"; label: "after " + Packages.toolName; onClicked: root.act(() => Shutdown.whenEmergeDone()) }
        Capsule { visible: Shutdown.pending; icon: "close"; label: "cancel"; onClicked: root.act(() => Shutdown.cancel()) }
    }
    }
}
