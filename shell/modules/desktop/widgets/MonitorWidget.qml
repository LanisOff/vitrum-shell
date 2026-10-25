import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components

/*
 * The last three minutes of the processor, memory and network as graphs
 * (SysInfo, and /proc/net/dev sampled every 2 s).
 *   M   the header; a row per graph: the name and the value on one line at
 *       the left, the graph filling the rest
 *   L   as M, taller: the value big under the name, the upload under it
 *   XL  as L, with what uses the processor most at the right
 * options: cpu, memory, network (which graphs show). The network graph is
 * two lines: down turning from the accent to accent2, up in a second ink.
 * In a gallery card nothing is sampled: a made-up three minutes stands in.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "L"
    property bool preview: false
    signal optionsEdited(var options)

    readonly property int points: 90                    // 2 s apart: three minutes
    property var cpu: []
    property var mem: []
    property var down: []                               // bytes/s
    property var up: []
    property real downNow: 0
    property real upNow: 0
    property var procs: []                              // [{ name, cpu }]

    Component.onCompleted: { SysInfo.subscribe(); Qt.callLater(() => root.started = true); }
    Component.onDestruction: SysInfo.unsubscribe()
    // preview is set just after the widget is made: wait for it before sampling.
    property bool started: false
    readonly property bool sampling: started && !preview
    readonly property bool wide: sizeClass === "XL" || (width > 440 && height > 240)

    function push(list, v) { const l = list.concat([v]); return l.length > points ? l.slice(l.length - points) : l; }
    property var _lastNet: null
    Timer {
        interval: 2000; repeat: true; running: root.sampling; triggeredOnStart: true
        onTriggered: {
            root.cpu = root.push(root.cpu, SysInfo.cpuUsage);
            root.mem = root.push(root.mem, SysInfo.memoryUsage);
            if (!sample.running) sample.running = true;
        }
    }
    Process {
        id: sample
        // The processes only when there is room to list them.
        command: ["sh", "-c", "awk 'NR>2 && $1 !~ /^lo:/ {split($0,a,\":\"); split(a[2],f,\" \"); rx+=f[1]; tx+=f[9]} END {print rx, tx}' /proc/net/dev" +
                              (root.wide ? "; ps -eo comm,%cpu --sort=-%cpu --no-headers | head -n 5" : "")]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const f = (lines[0] || "").trim().split(/\s+/);
                const rx = parseFloat(f[0]) || 0, tx = parseFloat(f[1]) || 0, now = Date.now();
                if (root._lastNet) {
                    const dt = (now - root._lastNet.t) / 1000;
                    root.downNow = Math.max(0, (rx - root._lastNet.rx) / dt);
                    root.upNow = Math.max(0, (tx - root._lastNet.tx) / dt);
                    root.down = root.push(root.down, root.downNow);
                    root.up = root.push(root.up, root.upNow);
                }
                root._lastNet = { rx: rx, tx: tx, t: now };
                root.procs = lines.slice(1).map(l => { const m = l.trim().match(/^(.*\S)\s+([\d.]+)$/); return m ? { name: m[1], cpu: parseFloat(m[2]) } : null; }).filter(x => x);
            }
        }
    }

    // ---- the sample: a made-up three minutes.
    readonly property var fake: {
        const c = [], m = [], d = [], u = [];
        for (let i = 0; i < points; i++) {
            c.push(0.22 + 0.12 * Math.sin(i / 6) + 0.06 * Math.sin(i / 1.7) + (i % 23 === 0 ? 0.25 : 0));
            m.push(0.46 + 0.03 * Math.sin(i / 17) + i * 0.0004);
            d.push(Math.max(0, 600000 + 500000 * Math.sin(i / 9) + 250000 * Math.sin(i / 2.2)));
            u.push(Math.max(0, 90000 + 60000 * Math.sin(i / 5 + 1)));
        }
        return { cpu: c, mem: m, down: d, up: u,
                 procs: [{ name: "firefox", cpu: 14.2 }, { name: "quickshell", cpu: 4.1 }, { name: "niri", cpu: 2.3 }, { name: "pipewire", cpu: 1.2 }, { name: "kitty", cpu: 0.6 }] };
    }
    readonly property var cpuS: preview ? fake.cpu : cpu
    readonly property var memS: preview ? fake.mem : mem
    readonly property var downS: preview ? fake.down : down
    readonly property var upS: preview ? fake.up : up
    readonly property var procsS: preview ? fake.procs : procs
    function last(l) { return l.length ? l[l.length - 1] : 0; }
    // Scaled to what is there (at least `floor`): at 3 % a 0–100 % graph is a flat line.
    function scaleTop(l, floor) { return Math.max(floor, Math.max.apply(null, l.length ? l : [0]) * 1.25); }
    readonly property real netTop: Math.max(65536, Math.max.apply(null, downS.concat(upS, [0])) * 1.15)
    function rate(b) { return b >= 1048576 ? { n: (b / 1048576).toFixed(1), u: "MB/s" } : { n: String(Math.round(b / 1024)), u: "KB/s" }; }

    readonly property var graphs: {
        const g = [];
        if (options.cpu !== false) {
            const v = preview ? last(fake.cpu) : SysInfo.cpuUsage;
            g.push({ key: "cpu", label: "Processor", n: String(Math.round(v * 100)), u: "%" });
        }
        if (options.memory !== false) {
            const v = preview ? last(fake.mem) * 32 : SysInfo.memoryUsedGB;
            g.push({ key: "mem", label: "Memory", n: v.toFixed(1), u: "GB" });
        }
        if (options.network !== false) {
            const d = rate(preview ? last(fake.down) : downNow), u = rate(preview ? last(fake.up) : upNow);
            g.push({ key: "net", label: "Network", n: d.n, u: d.u, up: "↑ " + u.n + " " + u.u });
        }
        return g;
    }

    WidgetHeader {
        id: head
        icon: "graph"; title: "Monitor"
        trailing: "3 min"
    }
    WidgetEmpty {
        visible: root.graphs.length === 0
        icon: "graph"
        text: "Turn a graph on in the widget's options"
    }

    // ---- the graphs, a row each.
    Column {
        id: rows
        visible: root.graphs.length > 0
        anchors { left: parent.left; top: head.bottom; bottom: parent.bottom; topMargin: Tokens.gap }
        width: root.wide && root.procsS.length > 0 ? (root.width - Tokens.gap * 2) * 0.6 : root.width
        spacing: Tokens.gap
        readonly property int n: Math.max(1, root.graphs.length)
        readonly property real rowH: Math.max(20, Math.min(Tokens.islandHeight * 3.2, (height - (n - 1) * spacing) / n))
        // Short rows: the name and the value side by side; tall: stacked.
        readonly property bool compact: rowH < Tokens.textSmall * 3.4
        readonly property real blockW: compact ? Math.min(150, width * 0.44) : Math.min(130, width * 0.3)

        Repeater {
            model: root.graphs
            delegate: Item {
                id: row
                required property var modelData
                readonly property bool net: modelData.key === "net"
                width: rows.width; height: rows.rowH

                // Short: "Processor  23 %"; for the network the two rates.
                Item {
                    visible: rows.compact
                    width: rows.blockW; height: parent.height
                    Label {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        width: Math.max(0, parent.width - shortValue.implicitWidth - Tokens.gap)
                        text: row.net ? "↓ " + modelData.n + " " + modelData.u : modelData.label
                        role: row.net ? "text" : "dim"; size: Tokens.textSmall; numeric: row.net
                    }
                    Label {
                        id: shortValue
                        anchors { right: parent.right; rightMargin: Tokens.gap * 0.5; verticalCenter: parent.verticalCenter }
                        text: row.net ? modelData.up : modelData.n + " " + modelData.u
                        color: row.net ? Colors.ink(120) : Colors.text
                        size: Tokens.textSmall; numeric: true; font.weight: Font.Medium
                    }
                }
                // Tall: the name, the value big, the upload under it.
                Column {
                    visible: !rows.compact
                    width: rows.blockW
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    Label { width: parent.width; text: modelData.label; role: "dim"; size: Tokens.textSmall }
                    Metric {
                        value: modelData.n; unit: modelData.u
                        size: Math.max(Tokens.textLarge, Math.min(30, Math.round(rows.rowH * 0.34)))
                    }
                    Label {
                        visible: row.net
                        text: modelData.up || ""
                        color: Colors.ink(120); size: Tokens.textSmall; numeric: true
                    }
                }

                Item {
                    id: plot
                    anchors { left: parent.left; leftMargin: rows.blockW + Tokens.gap; right: parent.right; top: parent.top; bottom: parent.bottom }
                    Rectangle { width: parent.width; height: Tokens.hairline; anchors.bottom: parent.bottom; color: Colors.alpha(Colors.text, 0.08) }
                    Sparkline {
                        anchors.fill: parent
                        values: row.net ? root.downS : modelData.key === "cpu" ? root.cpuS : root.memS
                        max: row.net ? root.netTop : root.scaleTop(values, modelData.key === "mem" ? 0.25 : 0.2)
                    }
                    Sparkline {
                        visible: row.net
                        anchors.fill: parent
                        values: row.net ? root.upS : []
                        max: root.netTop
                        color: Colors.ink(120)
                        fill: false
                        lineWidth: 1.5
                    }
                }
            }
        }
    }

    // ---- XL: what uses the processor most.
    Column {
        visible: root.wide && root.procsS.length > 0
        anchors { right: parent.right; top: head.bottom; topMargin: Tokens.gap }
        width: (root.width - Tokens.gap * 2) * 0.4
        spacing: Tokens.gap * 0.9
        Label { text: "Top processes"; role: "dim"; size: Tokens.textSmall }
        Repeater {
            model: root.wide ? root.procsS : []
            // How much of one core each takes: a whole core fills the bar.
            delegate: Meter {
                required property var modelData
                group: "widgets"
                width: parent.width
                kind: "linear"
                thickness: 4
                value: modelData.cpu / 100
                label: modelData.name
                trailing: modelData.cpu.toFixed(0) + "%"
            }
        }
    }
}
