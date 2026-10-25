import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components
import "../../../lib/procs.js" as Lib

/*
 * What works the machine hardest: the top processes by processor or memory
 * (/proc, read every 3 s; two readings give each process's share).
 *   M   the header; a row each — the app's icon (or a line glyph), the name,
 *       a small meter and the percentage — as many as fit
 *   L   the same, taller: under each name the other measure, and how many
 *       processes a name adds up
 * A share is of the whole machine, so the meters never run past full.
 * options: by (cpu | memory), count (how many at most), group (processes of
 * one name as one row: a browser's many).
 * In a gallery card, sample processes; nothing is read.
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
    readonly property bool live: started && !preview && root.visible && !GameMode.active

    readonly property bool byMemory: options.by === "memory"
    readonly property int count: Math.max(1, Number(options.count) || 5)
    readonly property bool group: options.group !== false

    property var last: null
    property var found: []
    property bool measured: false
    Process {
        id: reader
        command: ["sh", "-c", "echo \"page $(getconf PAGESIZE)\"; grep '^MemTotal:' /proc/meminfo; head -n 1 /proc/stat; cat /proc/[0-9]*/stat 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const cur = Lib.parseSample(text);
                root.found = Lib.top(root.last, cur, root.byMemory ? "memory" : "cpu", 8, root.group);
                // The first reading has no shares yet: the second follows soon.
                if (!root.last) soon.restart(); else root.measured = true;
                root.last = cur;
            }
        }
    }
    function read() { if (!reader.running) reader.running = true; }
    Timer { interval: 3000; repeat: true; running: root.live; triggeredOnStart: true; onTriggered: root.read() }
    Timer { id: soon; interval: 800; onTriggered: if (root.live) root.read() }
    // A new grouping or measure shows at the next reading, not three seconds on.
    onByMemoryChanged: if (live) read()
    onGroupChanged: if (live) read()
    onLiveChanged: if (!live) { last = null; measured = false; }

    readonly property var sample: [
        { name: "firefox", cpu: 0.184, mem: 0.142, bytes: 2.3e9, count: 14 },
        { name: "kitty", cpu: 0.061, mem: 0.012, bytes: 1.9e8, count: 2 },
        { name: "qs", cpu: 0.032, mem: 0.034, bytes: 5.4e8, count: 1 },
        { name: "niri", cpu: 0.021, mem: 0.016, bytes: 2.6e8, count: 1 },
        { name: "pipewire", cpu: 0.008, mem: 0.004, bytes: 6.2e7, count: 3 }
    ]
    readonly property var procs: (preview ? sample.slice().sort((a, b) => byMemory ? b.mem - a.mem : b.cpu - a.cpu) : found).slice(0, count)
    function share(p) { return byMemory ? p.mem : p.cpu; }
    function tint(p) { return share(p) > 0.5 ? Colors.danger : share(p) > 0.25 ? Colors.warning : Colors.accent; }
    function detail(p) {
        const other = byMemory ? Lib.percent(p.cpu) + " processor" : Lib.size(p.bytes);
        return p.count > 1 ? other + " · " + p.count + " processes" : other;
    }

    WidgetHeader {
        id: head
        icon: "processes"; title: "Top processes"
        trailing: root.byMemory ? "Memory" : "Processor"
    }
    WidgetEmpty {
        visible: !root.preview && root.procs.length === 0
        icon: "processes"
        text: root.measured || root.byMemory ? "No processes" : "Measuring…"
    }

    Column {
        id: rows
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: Tokens.gap * 0.5; bottom: parent.bottom }
        readonly property bool tall: root.sizeClass === "L" || root.sizeClass === "XL"
        readonly property real rowH: Math.round(Tokens.textSize * (tall ? 2.9 : 1.95))
        readonly property int fits: Math.max(1, Math.floor((height + spacing) / (rowH + spacing)))
        spacing: Math.round(Tokens.gap * 0.2)
        Repeater {
            model: root.procs.slice(0, rows.fits)
            delegate: Item {
                id: row
                required property var modelData
                readonly property var app: Apps.forAppId(modelData.name)
                width: rows.width; height: rows.rowH
                // The app's icon when the name is an app's; else a plain line glyph.
                Item {
                    id: lead
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(Tokens.textSize * (rows.tall ? 1.9 : 1.45)); height: width
                    IconImage {
                        anchors.centerIn: parent
                        visible: row.app !== null && source != ""
                        implicitSize: parent.width
                        source: row.app ? Apps.iconSource(row.app.icon) : ""
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: row.app === null
                        name: "terminal"
                        size: Math.round(parent.width * 0.78)
                        color: Colors.textDim
                    }
                }
                Column {
                    anchors { left: lead.right; leftMargin: Tokens.gap * 0.7; right: bar.left; rightMargin: Tokens.gap; verticalCenter: parent.verticalCenter }
                    Label {
                        width: parent.width
                        text: row.app ? row.app.name : row.modelData.name
                        font.weight: Font.Medium
                        size: rows.tall ? Tokens.textSize : Tokens.textSmall + 1
                    }
                    Label {
                        visible: rows.tall
                        width: parent.width
                        text: root.detail(row.modelData)
                        role: "dim"; size: Tokens.textSmall; numeric: true
                    }
                }
                Meter {
                    id: bar
                    group: "widgets"
                    anchors { right: pct.left; rightMargin: Tokens.gap * 0.8; verticalCenter: parent.verticalCenter }
                    width: Math.round(rows.width * 0.28)
                    thickness: rows.tall ? 6 : 4
                    value: root.share(row.modelData)
                    color: root.tint(row.modelData)
                }
                Label {
                    id: pct
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: Math.round(Tokens.textSmall * 3.4)
                    horizontalAlignment: Text.AlignRight
                    text: Lib.percent(root.share(row.modelData))
                    numeric: true; size: Tokens.textSmall; font.weight: Font.Medium
                }
            }
        }
    }
}
