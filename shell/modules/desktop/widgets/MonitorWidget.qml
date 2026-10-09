import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components

/*
 * The last three minutes of CPU, GPU, memory and network as small graphs,
 * and what uses the CPU most right now.
 */
Item {
    id: root
    property var options: ({})
    readonly property int points: 90                    // 2 s apart: three minutes
    property var cpu: []
    property var gpu: []
    property var mem: []
    property var net: []                                // bytes/s, both ways
    property real netNow: 0
    property real netMax: 1
    property var procs: []                              // [{ name, cpu }]

    Component.onCompleted: SysInfo.subscribe()
    Component.onDestruction: SysInfo.unsubscribe()

    function push(list, v) { const l = list.concat([v]); return l.length > points ? l.slice(l.length - points) : l; }
    property var _lastNet: null
    Timer {
        interval: 2000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: {
            root.cpu = root.push(root.cpu, SysInfo.cpuUsage);
            root.gpu = root.push(root.gpu, SysInfo.gpuAvailable ? SysInfo.gpuUsage : 0);
            root.mem = root.push(root.mem, SysInfo.memoryUsage);
            if (!sample.running) sample.running = true;
        }
    }
    Process {
        id: sample
        command: ["sh", "-c", "awk 'NR>2 && $1 !~ /^lo:/ {split($0,a,\":\"); split(a[2],f,\" \"); rx+=f[1]; tx+=f[9]} END {print rx+tx}' /proc/net/dev; " +
                              "ps -eo comm,%cpu --sort=-%cpu --no-headers | head -n 5"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const bytes = parseFloat(lines[0]) || 0, now = Date.now();
                if (root._lastNet) {
                    const rate = Math.max(0, (bytes - root._lastNet.b) / ((now - root._lastNet.t) / 1000));
                    root.netNow = rate;
                    root.net = root.push(root.net, rate);
                    root.netMax = Math.max(1024 * 64, ...root.net);
                }
                root._lastNet = { b: bytes, t: now };
                root.procs = lines.slice(1).map(l => { const m = l.trim().match(/^(.*\S)\s+([\d.]+)$/); return m ? { name: m[1], cpu: parseFloat(m[2]) } : null; }).filter(x => x);
            }
        }
    }
    function rate(b) { return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB/s" : Math.round(b / 1024) + " KB/s"; }

    component Graph: Item {
        id: g
        property string title: ""
        property string value: ""
        property var series: []
        property real max: 1
        /// Scale to what is there (at least `floor`): at 3 % a 0–100 % graph was a flat line.
        property bool autoscale: false
        property real floor: 0.2
        readonly property real scaleTop: autoscale ? Math.max(floor, Math.max.apply(null, series.length ? series : [0]) * 1.25) : max
        property color tint: Colors.accent
        Label { id: t; text: g.title; size: Tokens.textSmall; role: "dim" }
        Label { anchors.right: parent.right; text: g.value; size: Tokens.textSmall; numeric: true; font.weight: Font.DemiBold }
        Canvas {
            id: c
            anchors { left: parent.left; right: parent.right; top: t.bottom; bottom: parent.bottom; topMargin: 2 }
            property var d: g.series
            onDChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const n = root.points, w = width, h = height, m = g.scaleTop || 1;
                ctx.strokeStyle = Colors.alpha(Colors.text, 0.08); ctx.lineWidth = 1;
                ctx.beginPath(); ctx.moveTo(0, h - 0.5); ctx.lineTo(w, h - 0.5); ctx.stroke();
                if (d.length < 2) return;
                const x = i => w - (d.length - 1 - i) * (w / (n - 1)), y = v => h - Math.min(1, v / m) * (h - 2) - 1;
                ctx.beginPath(); ctx.moveTo(x(0), h);
                for (let i = 0; i < d.length; i++) ctx.lineTo(x(i), y(d[i]));
                ctx.lineTo(x(d.length - 1), h); ctx.closePath();
                const grad = ctx.createLinearGradient(0, 0, 0, h);
                grad.addColorStop(0, Colors.alpha(g.tint, 0.5)); grad.addColorStop(1, Colors.alpha(g.tint, 0.04));
                ctx.fillStyle = grad; ctx.fill();
                ctx.beginPath(); ctx.moveTo(x(0), y(d[0]));
                for (let i = 1; i < d.length; i++) ctx.lineTo(x(i), y(d[i]));
                ctx.lineJoin = "round"; ctx.lineCap = "round";
                ctx.strokeStyle = g.tint; ctx.lineWidth = 2; ctx.stroke();
            }
        }
    }

    WidgetHeader { id: head; icon: "cpu"; title: "Activity"; hue: 100 }
    Column {
        anchors { fill: parent; topMargin: head.height + Tokens.gap * 0.5 }
        spacing: Tokens.gap
        Grid {
            columns: 2
            spacing: Tokens.gap
            readonly property real cw: (root.width - Tokens.gap) / 2
            Graph { width: parent.cw; height: Tokens.islandHeight * 1.9; title: "CPU"; value: Math.round(SysInfo.cpuUsage * 100) + "%"; series: root.cpu; autoscale: true; tint: Colors.accent }
            Graph { width: parent.cw; height: Tokens.islandHeight * 1.9; title: "GPU"; value: SysInfo.gpuAvailable ? Math.round(SysInfo.gpuUsage * 100) + "% · " + Math.round(SysInfo.gpuTemp) + "°" : "—"; series: root.gpu; autoscale: true; tint: Colors.accent }
            Graph { width: parent.cw; height: Tokens.islandHeight * 1.9; title: "Memory"; value: SysInfo.memoryUsedGB.toFixed(1) + " GB"; series: root.mem; autoscale: true; floor: 0.25; tint: Colors.accent }
            Graph { width: parent.cw; height: Tokens.islandHeight * 1.9; title: "Network"; value: root.rate(root.netNow); series: root.net; max: root.netMax; tint: Colors.accent }
        }
        Column {
            width: parent.width
            spacing: 1
            Repeater {
                model: root.procs
                Item {
                    required property var modelData
                    width: parent.width; height: Tokens.textSmall + 10
                    Label { id: pname; text: modelData.name; size: Tokens.textSmall; width: parent.width * 0.42; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                    // How much of one core it takes, as a thin bar (a whole core fills it).
                    Rectangle {
                        anchors { left: pname.right; leftMargin: Tokens.gap; right: pval.left; rightMargin: Tokens.gap; verticalCenter: parent.verticalCenter }
                        height: 4; radius: 2
                        color: Colors.alpha(Colors.text, 0.08)
                        Rectangle {
                            height: parent.height; radius: 2
                            width: parent.width * Math.min(1, modelData.cpu / 100)
                            color: Colors.alpha(Colors.accent, 0.85)
                            Behavior on width { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }
                        }
                    }
                    Label { id: pval; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: modelData.cpu.toFixed(0) + "%"; size: Tokens.textSmall; numeric: true; role: "dim"; width: 34; horizontalAlignment: Text.AlignRight }
                }
            }
        }
    }
}
