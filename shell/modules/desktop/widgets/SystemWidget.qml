import QtQuick
import qs.services
import qs.theme
import qs.components

/*
 * How hard the machine works (SysInfo): processor, memory, GPU, temperature.
 *   S   the processor as one big ring, the load inside, its name under it
 *   M   the header; the meters in a row (rings) or two columns (bars)
 *   L   as M, larger: rings two by two, bars one under the other
 * options: cpu, memory, temperature (which meters show; the GPU shows when
 * there is one), style (rings: circular meters; bars: linear ones, named).
 * The layout is picked from the room there is, so in-between sizes hold up.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    Component.onCompleted: SysInfo.subscribe()
    Component.onDestruction: SysInfo.unsubscribe()

    readonly property bool bars: options.style === "bars"
    // A meter turns red near the top; the temperature turns orange when warm first.
    function tone(v) { return v > 0.85 ? Colors.danger : Colors.accent; }
    readonly property var gauges: {
        const g = [];
        if (options.cpu !== false)
            g.push({ label: "CPU", value: SysInfo.cpuUsage, num: String(Math.round(SysInfo.cpuUsage * 100)), unit: "%", tint: tone(SysInfo.cpuUsage) });
        if (options.memory !== false)
            g.push({ label: "Memory", value: SysInfo.memoryUsage, num: String(Math.round(SysInfo.memoryUsage * 100)), unit: "%", tint: tone(SysInfo.memoryUsage),
                     detail: SysInfo.memoryUsedGB.toFixed(1) + " GB" });
        if (SysInfo.gpuAvailable)
            g.push({ label: "GPU", value: SysInfo.gpuUsage, num: String(Math.round(SysInfo.gpuUsage * 100)), unit: "%", tint: tone(SysInfo.gpuUsage) });
        if (options.temperature !== false) {
            const t = SysInfo.cpuTemp;
            g.push({ label: "Temperature", short: "Temp", value: Math.min(1, t / 100), num: t > 0 ? String(Math.round(t)) : "—", unit: t > 0 ? "°" : "",
                     tint: t >= 85 ? Colors.danger : t >= 70 ? Colors.meaning(0.07) : Colors.accent });
        }
        return g;
    }
    readonly property int count: gauges.length
    // At S the processor, or whatever comes first when it is switched off.
    readonly property var lead: count > 0 ? gauges[0] : null

    WidgetHeader {
        id: head
        visible: root.sizeClass !== "S"
        height: visible ? implicitHeight : 0
        icon: "cpu"; title: "System"
    }
    WidgetEmpty {
        visible: root.count === 0
        icon: "cpu"
        text: "Turn a meter on in the widget's options"
    }

    // ---- S: one big ring.
    Column {
        visible: root.sizeClass === "S" && root.lead !== null
        anchors.centerIn: parent
        spacing: Tokens.gap * 0.4
        readonly property real d: Math.max(48, Math.min(root.width, root.height - Tokens.textSmall - Tokens.gap * 0.4 - 4) * 0.92)
        Meter {
            id: big
            group: "widgets"
            anchors.horizontalCenter: parent.horizontalCenter
            kind: "circular"
            width: parent.d; height: parent.d
            thickness: Math.max(6, width * 0.085)
            value: root.lead ? root.lead.value : 0
            color: root.lead ? root.lead.tint : Colors.accent
            Metric {
                anchors.centerIn: parent
                value: root.lead ? root.lead.num : ""
                unit: root.lead ? root.lead.unit : ""
                size: Math.round(big.width * 0.3)
            }
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.lead ? root.lead.label : ""
            role: "dim"; size: Tokens.textSmall
        }
    }

    // ---- M and L: the meters, under the header.
    Item {
        id: area
        visible: root.sizeClass !== "S" && root.count > 0
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; topMargin: Tokens.gap }
        readonly property real gap: Tokens.gap
        readonly property real nameH: Tokens.textSmall + 6

        // Rings: the grid (columns × rows) that gives the largest ring.
        readonly property var ringFit: {
            let best = { cols: 1, d: 0 };
            for (let cols = 1; cols <= root.count; cols++) {
                const rows = Math.ceil(root.count / cols);
                const cw = (width - (cols - 1) * gap) / cols;
                const ch = (height - (rows - 1) * gap) / rows;
                const d = Math.min(cw * 0.78, ch - nameH - 4, Tokens.islandHeight * 4);
                if (d > best.d + 0.5) best = { cols: cols, d: d };
            }
            return best;
        }
        // Bars: as many rows as fit, then another column.
        readonly property real barRowH: Tokens.textSmall + 10 + barThick
        readonly property real barThick: height > Tokens.islandHeight * 5 ? 8 : 6
        readonly property int barRows: Math.max(1, Math.min(root.count, Math.floor((height + gap) / (barRowH + gap))))
        readonly property int barCols: Math.ceil(root.count / barRows)

        Grid {
            id: ringGrid
            visible: !root.bars
            anchors.centerIn: parent
            columns: area.ringFit.cols
            columnSpacing: area.gap
            rowSpacing: area.gap
            readonly property real cellW: (area.width - (columns - 1) * area.gap) / columns
            Repeater {
                model: root.bars ? [] : root.gauges
                delegate: Column {
                    required property var modelData
                    width: ringGrid.cellW
                    spacing: 4
                    Meter {
                        group: "widgets"
                        anchors.horizontalCenter: parent.horizontalCenter
                        kind: "circular"
                        width: Math.max(32, area.ringFit.d); height: width
                        thickness: Math.max(4, width * 0.1)
                        value: modelData.value
                        color: modelData.tint
                        trailing: modelData.num + modelData.unit
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(implicitWidth, parent.width)
                        text: parent.width < 90 && modelData.short ? modelData.short : modelData.label
                        role: "dim"; size: Tokens.textSmall
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        Grid {
            id: barGrid
            visible: root.bars
            width: area.width
            anchors.verticalCenter: parent.verticalCenter
            // Rows only: the columns follow from them (both set fell out of step with the model).
            columnSpacing: area.gap * 1.5
            // Rows spread over the height, so a tall widget is not top-heavy.
            rowSpacing: area.barRows > 1 ? Math.min(area.gap * 2.5, Math.max(area.gap, (area.height - area.barRows * area.barRowH) / (area.barRows - 1))) : 0
            flow: Grid.TopToBottom
            rows: area.barRows
            Repeater {
                model: root.bars ? root.gauges : []
                delegate: Meter {
                    required property var modelData
                    group: "widgets"
                    width: (barGrid.width - (area.barCols - 1) * barGrid.columnSpacing) / area.barCols
                    kind: "linear"
                    thickness: area.barThick
                    value: modelData.value
                    color: modelData.tint
                    label: modelData.label
                    trailing: modelData.detail && width > 200 ? modelData.detail + " · " + modelData.num + modelData.unit : modelData.num + modelData.unit
                }
            }
        }
    }
}
