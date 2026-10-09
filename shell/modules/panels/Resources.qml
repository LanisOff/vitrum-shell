import QtQuick
import qs.services
import qs.theme
import qs.components

// System resources in detail: a bar per figure, plus uptime and model.
Column {
    id: root
    spacing: Tokens.gap
    width: Tokens.islandHeight * 13
    Component.onCompleted: SysInfo.subscribe()
    Component.onDestruction: SysInfo.unsubscribe()

    component Meter: Column {
        property string icon: "cpu"
        property string title: ""
        property string value: ""
        property real fraction: 0
        width: root.width
        spacing: 4
        Row {
            width: parent.width; spacing: Tokens.gap / 2
            Icon { name: parent.parent.icon; color: Colors.textDim }
            Label { text: parent.parent.title; width: parent.width - Tokens.iconSize * 8 - Tokens.gap }
            Label { text: parent.parent.value; numeric: true; horizontalAlignment: Text.AlignRight; width: Tokens.iconSize * 7 }
        }
        Rectangle {
            width: parent.width; height: 6; radius: 3; color: Colors.alpha(Colors.text, 0.12)
            Rectangle {
                height: parent.height; radius: 3
                width: parent.width * Math.max(0, Math.min(1, parent.parent.fraction))
                color: parent.parent.fraction > 0.9 ? Colors.danger : Colors.accent
                Behavior on width { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }
            }
        }
    }

    Meter { icon: "cpu"; title: SysInfo.cpuModel || "Processor"; value: Math.round(SysInfo.cpuUsage * 100) + "%"; fraction: SysInfo.cpuUsage }
    Meter { icon: "memory"; title: "Memory"; value: SysInfo.memoryUsedGB.toFixed(1) + " / " + SysInfo.memoryTotalGB.toFixed(0) + " GB"; fraction: SysInfo.memoryUsage }
    Meter { visible: SysInfo.cpuTemp > 0; icon: "temperature"; title: "CPU temperature"; value: Math.round(SysInfo.cpuTemp) + "°C"; fraction: SysInfo.cpuTemp / 100 }
    Meter { visible: SysInfo.gpuAvailable; icon: "gpu"; title: SysInfo.gpuModel || "Graphics"; value: Math.round(SysInfo.gpuUsage * 100) + "% · " + Math.round(SysInfo.gpuTemp) + "°C"; fraction: SysInfo.gpuUsage }
    Label { text: (SysInfo.hostname ? SysInfo.hostname + " · " : "") + (SysInfo.uptime ? "up " + SysInfo.uptime : ""); role: "dim"; size: Tokens.textSmall }
}
