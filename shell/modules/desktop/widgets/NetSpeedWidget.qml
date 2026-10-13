import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components

/*
 * How fast the network moves right now (/proc/net/dev, once a second).
 *   S   down large, up under it; the last minute as a graph along the bottom
 *   M   the header (the interface at its end); down and up, the graph beside
 * The graph is both directions on one scale: down in the accent, up a second ink.
 * options: iface (the interface; empty: the one that has carried the most),
 * graph.
 * In a gallery card, sample rates; nothing is read.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    // preview is set after Component.onCompleted: start a turn later, once it is known.
    property bool started: false
    Component.onCompleted: Qt.callLater(() => root.started = true)
    readonly property bool live: started && !preview

    readonly property string wantedIface: String(options.iface || "").trim()
    readonly property bool graph: options.graph !== false
    readonly property int points: 60

    property string iface: ""
    property bool read: false
    property bool missing: false        // the interface asked for is not there
    property real down: 0               // bytes/s
    property real up: 0
    property var downs: []
    property var ups: []
    property var _last: null            // { t, ifaces: { name: { rx, tx } } }

    readonly property var sampleDowns: Array.from({ length: 60 }, (_, i) => Math.max(0, 1.6e6 + 1.1e6 * Math.sin(i / 5) + 4e5 * Math.sin(i * 1.7)))
    readonly property var sampleUps: Array.from({ length: 60 }, (_, i) => Math.max(0, 2.2e5 + 1.4e5 * Math.sin(i / 4 + 1)))
    readonly property real shownDown: preview ? 2.4e6 : down
    readonly property real shownUp: preview ? 1.8e5 : up
    readonly property var shownDowns: preview ? sampleDowns : downs
    readonly property var shownUps: preview ? sampleUps : ups
    readonly property string shownIface: preview ? "wlan0" : iface
    readonly property bool ready: preview || (read && !missing)
    readonly property real peak: Math.max(1024 * 64, ...shownDowns, ...shownUps)

    FileView {
        id: dev
        path: root.live ? "/proc/net/dev" : ""
        printErrors: false
        onLoaded: root.take(text())
    }
    Timer { interval: 1000; repeat: true; running: root.live; onTriggered: dev.reload() }
    onWantedIfaceChanged: { downs = []; ups = []; }

    function push(list, v) { const l = list.concat([v]); return l.length > points ? l.slice(l.length - points) : l; }
    function take(text) {
        const now = Date.now(), ifaces = {};
        for (const l of String(text || "").split("\n").slice(2)) {
            const c = l.indexOf(":");
            if (c < 0) continue;
            const name = l.slice(0, c).trim(), f = l.slice(c + 1).trim().split(/\s+/).map(Number);
            if (name === "lo" || f.length < 9) continue;
            ifaces[name] = { rx: f[0], tx: f[8] };
        }
        // The busiest: the most carried since boot, so the pick holds still.
        let pick = wantedIface;
        if (!pick) {
            let most = -1;
            for (const n in ifaces) if (ifaces[n].rx + ifaces[n].tx > most) { most = ifaces[n].rx + ifaces[n].tx; pick = n; }
        }
        read = true;
        missing = !ifaces[pick];
        if (pick !== iface) { iface = pick; downs = []; ups = []; _last = null; }
        const was = _last && _last.ifaces[pick], cur = ifaces[pick];
        if (was && cur) {
            const dt = Math.max(0.001, (now - _last.t) / 1000);
            // A counter that went back (the interface came up again) is no traffic.
            down = Math.max(0, (cur.rx - was.rx) / dt);
            up = Math.max(0, (cur.tx - was.tx) / dt);
            downs = push(downs, down);
            ups = push(ups, up);
        }
        _last = { t: now, ifaces: ifaces };
    }
    // → [number, unit]
    function rate(b) {
        if (b < 1024) return [String(Math.round(b)), "B/s"];
        if (b < 1048576) { const k = b / 1024; return [k < 10 ? k.toFixed(1) : String(Math.round(k)), "KB/s"]; }
        const m = b / 1048576;
        return [m < 100 ? m.toFixed(1) : String(Math.round(m)), "MB/s"];
    }

    WidgetHeader {
        id: head
        visible: root.sizeClass !== "S"
        height: visible ? implicitHeight : 0
        icon: "speed"; title: "Network"
        trailing: root.shownIface
    }
    WidgetEmpty {
        visible: !root.ready && root.read
        icon: "speed"
        text: root.wantedIface ? "No interface " + root.wantedIface : "No network interfaces"
    }

    // Both directions on one scale (given, not looked up: an inline component
    // does not see this file's ids).
    component Graph: Item {
        id: g
        property var downs: []
        property var ups: []
        property real peak: 1
        Sparkline { anchors.fill: parent; values: g.downs; max: g.peak; color: Colors.accent }
        Sparkline { anchors.fill: parent; values: g.ups; max: g.peak; color: Colors.ink(120); fill: false; lineWidth: 1.5 }
    }

    // ---- S: one glance.
    Item {
        id: small
        visible: root.ready && root.sizeClass === "S"
        anchors.fill: parent
        Graph {
            id: smallGraph
            visible: root.graph
            downs: root.shownDowns; ups: root.shownUps; peak: root.peak
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: root.graph ? parent.height * 0.3 : 0
        }
        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.graph ? -smallGraph.height / 2 - Tokens.gap * 0.25 : 0
            spacing: 2
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4
                Icon { name: "download"; color: Colors.accent; size: Tokens.iconSize; anchors.verticalCenter: parent.verticalCenter }
                Metric {
                    anchors.verticalCenter: parent.verticalCenter
                    value: root.rate(root.shownDown)[0]; unit: root.rate(root.shownDown)[1]
                    size: Math.max(20, Math.min(34, root.height * 0.2))
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4
                Icon { name: "upload"; color: Colors.ink(120); size: Tokens.textSmall + 2; anchors.verticalCenter: parent.verticalCenter }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.rate(root.shownUp).join(" ")
                    role: "dim"; size: Tokens.textSmall; numeric: true
                }
            }
        }
    }

    // ---- M: the two rates; the graph beside them.
    Column {
        id: rates
        visible: root.ready && root.sizeClass !== "S"
        anchors { left: parent.left; top: head.bottom; topMargin: Tokens.gap * 0.6 }
        width: root.graph ? Math.min(implicitWidth, root.width * 0.45) : root.width
        spacing: Tokens.gap * 0.4
        readonly property int big: Math.max(20, Math.min(34, (root.height - head.height) * 0.24))
        Repeater {
            model: [{ i: "download", t: "Download", v: root.shownDown, c: Colors.accent },
                    { i: "upload", t: "Upload", v: root.shownUp, c: Colors.ink(120) }]
            delegate: Row {
                required property var modelData
                spacing: Tokens.gap * 0.6
                Icon { name: modelData.i; color: modelData.c; size: Tokens.iconSize + 2; anchors.verticalCenter: parent.verticalCenter }
                Metric {
                    anchors.verticalCenter: parent.verticalCenter
                    value: root.rate(modelData.v)[0]; unit: root.rate(modelData.v)[1]
                    label: modelData.t
                    size: rates.big
                }
            }
        }
    }
    Graph {
        visible: root.ready && root.sizeClass !== "S" && root.graph
        downs: root.shownDowns; ups: root.shownUps; peak: root.peak
        anchors { left: rates.right; leftMargin: Tokens.gap * 1.5; right: parent.right; top: head.bottom; topMargin: Tokens.gap; bottom: parent.bottom }
    }
}
