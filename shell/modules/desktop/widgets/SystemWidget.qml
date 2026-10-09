import QtQuick
import qs.services
import qs.theme
import qs.components

// CPU, memory, GPU and temperature as rings: the value in the middle, the name
// under it. Four in a row when the widget is wide, two by two when it is not.
Item {
    id: root
    property var options: ({})
    property bool toned: false            // on a coloured plate: white ink
    Component.onCompleted: SysInfo.subscribe()
    Component.onDestruction: SysInfo.unsubscribe()

    readonly property var gauges: [
        { label: "CPU", tint: Colors.accent, value: SysInfo.cpuUsage, text: Math.round(SysInfo.cpuUsage * 100) + "%" },
        { label: "Memory", tint: Colors.accent, value: SysInfo.memoryUsage, text: Math.round(SysInfo.memoryUsage * 100) + "%" },
        { label: "GPU", tint: Colors.accent, value: SysInfo.gpuAvailable ? SysInfo.gpuUsage : 0, text: SysInfo.gpuAvailable ? Math.round(SysInfo.gpuUsage * 100) + "%" : "—" },
        // The temperature speaks only when it matters: orange warm, red hot.
        { label: "Temp", tint: SysInfo.cpuTemp >= 70 ? Colors.meaning(0.07) : Colors.accent, value: Math.min(1, SysInfo.cpuTemp / 100), text: SysInfo.cpuTemp > 0 ? Math.round(SysInfo.cpuTemp) + "°" : "—" }
    ]
    WidgetHeader { id: header; icon: "cpu"; title: "System"; hue: 0 }
    // Two by two under the header: each a ring with its name and value beside
    // it, so the rings take the cell's height and the text its width.
    readonly property real areaH: height - header.height - Tokens.gap
    readonly property real cellW: (width - Tokens.gap) / 2
    readonly property real cellH: (areaH - Tokens.gap) / 2
    readonly property real ring: Math.max(32, Math.min(cellH, cellW * 0.48))

    Grid {
        y: header.height + Tokens.gap
        columns: 2
        columnSpacing: Tokens.gap
        rowSpacing: Tokens.gap
        Repeater {
            model: root.gauges
            delegate: Row {
                required property var modelData
                width: root.cellW; height: root.cellH
                spacing: Tokens.gap
                Ring {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.ring; height: root.ring
                    thickness: Math.max(4, root.ring * 0.13)
                    value: modelData.value
                    color: modelData.value > 0.85 ? Colors.danger : root.toned ? "white" : modelData.tint
                    trackColor: root.toned ? Qt.rgba(1, 1, 1, 0.2) : Colors.alpha(Colors.text, 0.1)
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Label { text: modelData.label; size: Tokens.textSmall; color: root.toned ? Qt.rgba(1, 1, 1, 0.75) : Colors.textDim }
                    Label { text: modelData.text; numeric: true; font.weight: Font.DemiBold; size: Math.max(Tokens.textSize, root.ring * 0.34)
                            color: root.toned ? "white" : Colors.text }
                }
            }
        }
    }
}
