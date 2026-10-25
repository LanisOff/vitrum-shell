import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components

/*
 * How full the disks are (df, once a minute).
 *   S   the system disk as a ring, the space left under it
 *   M   the header; a bar for each disk with its used and total size, as
 *       many as fit
 *   L   the same, with room for more
 * A bar is the dichroic tint (the accent → accent2), amber over 80 %, red over 90 %.
 * options: mounts (the mount points shown, in that order; empty: every disk —
 * each device once, the boot partitions left out).
 * In a gallery card, sample disks; nothing runs.
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

    property var found: []              // [{ mount, device, size, used, avail }]
    property bool read: false
    readonly property var sampleDisks: [
        { mount: "/", device: "/dev/nvme0n1p2", size: 500e9, used: 231e9, avail: 269e9 },
        { mount: "/mnt/data", device: "/dev/sda1", size: 2000e9, used: 1684e9, avail: 316e9 },
        { mount: "/mnt/games", device: "/dev/nvme1n1p1", size: 1000e9, used: 574e9, avail: 426e9 }
    ]
    readonly property var all: preview ? sampleDisks : found
    readonly property var wanted: (options.mounts || []).map(m => String(m).trim().replace(/(.)\/+$/, "$1")).filter(m => m)
    readonly property var disks: {
        if (!wanted.length) return all;
        const out = [];
        for (const m of wanted) {
            const d = all.find(x => x.mount === m);
            if (d) out.push(d);
        }
        return out;
    }
    readonly property var system: disks.find(d => d.mount === "/") || disks[0] || null

    Process {
        id: df
        command: ["df", "-P", "-B1", "-x", "tmpfs", "-x", "devtmpfs", "-x", "squashfs", "-x", "overlay", "-x", "efivarfs"]
        stdout: StdioCollector { onStreamFinished: { root.found = root.parse(text); root.read = true; } }
    }
    Timer { interval: 60000; repeat: true; running: root.live; triggeredOnStart: true; onTriggered: if (!df.running) df.running = true }

    // Real devices only, each once: a btrfs volume mounted as / and /home is
    // one disk (the shortest mount point names it); boot partitions are noise.
    function parse(text) {
        const byDev = {};
        for (const l of String(text || "").split("\n").slice(1)) {
            const p = l.trim().split(/\s+/);
            if (p.length < 6 || p[0].indexOf("/dev/") !== 0 || p[0].indexOf("/dev/loop") === 0) continue;
            const d = { device: p[0], size: +p[1], used: +p[2], avail: +p[3], mount: p.slice(5).join(" ") };
            if (!(d.size > 0) || /^\/(boot|efi)(\/|$)/.test(d.mount)) continue;
            const had = byDev[d.device];
            if (!had || d.mount.length < had.mount.length) byDev[d.device] = d;
        }
        return Object.values(byDev).sort((a, b) => a.mount === "/" ? -1 : b.mount === "/" ? 1 : a.mount.localeCompare(b.mount));
    }
    function usage(d) { return d && d.size > 0 ? d.used / d.size : 0; }
    function tint(d) { const u = usage(d); return u > 0.9 ? Colors.danger : u > 0.8 ? Colors.warning : Colors.accent; }
    function name(d) { return d.mount === "/" ? "System" : d.mount; }
    // Sizes as df's are counted (1000s), terabytes from a thousand gigabytes up.
    function gb(b, unit) {
        const v = b / (unit === "TB" ? 1e12 : 1e9);
        return v >= 100 ? String(Math.round(v)) : v.toFixed(1);
    }
    function sizes(d) { const u = d.size >= 1e12 ? "TB" : "GB"; return gb(d.used, u) + " / " + gb(d.size, u) + " " + u; }
    function free(d) { const u = d.avail >= 1e12 ? "TB" : "GB"; return gb(d.avail, u) + " " + u + " free"; }

    WidgetHeader {
        id: head
        visible: root.sizeClass !== "S"
        height: visible ? implicitHeight : 0
        icon: "disk"; title: "Disks"
        trailing: root.system ? root.free(root.system) : ""
    }
    WidgetEmpty {
        visible: !root.disks.length && (root.read || root.preview)
        icon: "disk"
        text: root.wanted.length ? "None of these is mounted: " + root.wanted.join(", ") : "No disks"
    }

    // ---- S: the system disk.
    Column {
        visible: root.sizeClass === "S" && root.system !== null
        anchors.centerIn: parent
        spacing: Tokens.gap * 0.6
        Meter {
            group: "widgets"
            anchors.horizontalCenter: parent.horizontalCenter
            kind: "circular"
            width: Math.min(root.width, root.height) * 0.66; height: width
            value: root.usage(root.system)
            trailing: Math.round(root.usage(root.system) * 100) + "%"
            color: root.tint(root.system)
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.width; horizontalAlignment: Text.AlignHCenter
            text: root.system ? root.free(root.system) : ""
            role: "dim"; size: Tokens.textSmall; numeric: true
        }
    }

    // ---- M and L: a bar each, as many as fit.
    Column {
        id: rows
        visible: root.sizeClass !== "S"
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: Tokens.gap; bottom: parent.bottom }
        readonly property real rowH: Tokens.textSmall + 4 + 6 + 6
        spacing: Math.max(Tokens.gap, Math.min(Tokens.gap * 2, (height - fits * rowH) / Math.max(1, fits - 1)))
        readonly property int fits: Math.max(1, Math.floor((height + Tokens.gap) / (rowH + Tokens.gap)))
        Repeater {
            model: root.disks.slice(0, rows.fits)
            delegate: Meter {
                required property var modelData
                group: "widgets"
                width: rows.width
                label: root.name(modelData)
                trailing: root.sizes(modelData)
                value: root.usage(modelData)
                color: root.tint(modelData)
            }
        }
    }
}
