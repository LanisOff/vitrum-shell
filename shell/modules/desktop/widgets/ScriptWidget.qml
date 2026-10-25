import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import "../../../lib/widgets.js" as W

/*
 * A widget made of a command (widgets.custom; the editor's Custom tab): run
 * with sh every `interval` seconds, its output read by W.parseScriptOutput —
 * JSON { value, unit, title, subtitle, progress, items, icon, history }, or
 * lines (the value, a subtitle, then items) — and shown by a template:
 *   value     a big value, the subtitle under it
 *   progress  the value and a meter (progress 0..1)
 *   list      rows (items: text, or { label, value })
 *   graph     the value and a sparkline (history, else the values seen)
 *   text      everything, wrapped
 * A failing run keeps the last good output and shows stderr's first line.
 * Not run as a gallery card; the editor's form runs it for its preview (def + live).
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    property string type: ""
    signal optionsEdited(var options)
    /// A script entry given directly (the editor's form), instead of by type.
    property var def: null
    property bool live: !preview
    readonly property var s: def || CustomWidgets.script(type.indexOf("script:") === 0 ? type.slice(7) : "")
    readonly property int every: Math.max(1, Math.min(3600, Number(s && s.interval) || 10))
    readonly property string template: s && s.template ? s.template : "value"

    property var out: null
    property string err: ""
    property var seen: []
    readonly property var history: out && out.history.length ? out.history : seen
    readonly property bool small: sizeClass === "S"

    Process {
        id: proc
        // Bounded whatever the command does: half a minute, 64 KiB out, 4 KiB of
        // errors (a `tail -f` would otherwise keep the shell's memory growing).
        command: ["bash", "-c", 'timeout 30 sh -c "$1" 2> >(head -c 4096 >&2) | head -c 65536', "_", root.s ? root.s.command : "true"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) return;
                const o = W.parseScriptOutput(text);
                root.out = o;
                root.err = "";
                const n = parseFloat(o.value);
                if (isFinite(n)) root.seen = root.seen.concat([n]).slice(-60);
            }
        }
        stderr: StdioCollector { onStreamFinished: { const l = text.trim().split("\n")[0]; if (l) root.err = l.slice(0, 200); } }
        onExited: code => { if (code !== 0 && !root.err) root.err = "Exited with " + code; }
    }
    Timer {
        interval: root.every * 1000
        repeat: true; triggeredOnStart: true
        running: root.live && !!root.s && root.visible
        onTriggered: if (!proc.running) proc.running = true
    }
    // The command (or how it runs) changed: start over and run it now. Not on
    // every settings write — those hand back an equal script as a new object.
    readonly property string key: s ? JSON.stringify([s.command, s.interval, s.template]) : ""
    onKeyChanged: { out = null; err = ""; seen = []; if (live && s && !proc.running) proc.running = true; }

    WidgetHeader {
        id: head
        visible: !root.small
        height: visible ? implicitHeight : 0
        icon: root.out && root.out.icon ? root.out.icon : root.s ? root.s.icon || "code" : "code"
        title: root.out && root.out.title ? root.out.title : root.s ? root.s.name || "Script" : "Script"
    }
    WidgetEmpty {
        visible: !root.out
        icon: root.s ? root.s.icon || "code" : "help"
        text: !root.s ? "This script widget was deleted" : !root.live ? (root.s.name || "Script") : root.err ? root.err : "Running…"
    }

    Item {
        id: area
        visible: !!root.out
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: root.small ? 0 : Tokens.gap * 0.6; bottom: errLine.top }

        // value, progress, graph: the value first.
        Metric {
            id: metric
            visible: root.template !== "list" && root.template !== "text"
            anchors { left: parent.left; verticalCenter: root.template === "value" ? parent.verticalCenter : undefined; top: root.template === "value" ? undefined : parent.top }
            width: parent.width
            value: root.out ? root.out.value : ""
            unit: root.out ? root.out.unit : ""
            label: root.out ? root.out.subtitle : ""
            size: Math.max(22, Math.min(root.small ? parent.height * 0.42 : parent.height * 0.36, 52))
        }
        Meter {
            group: "widgets"
            visible: root.template === "progress"
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 4 }
            value: root.out && root.out.progress !== null ? root.out.progress : 0
            trailing: root.out && root.out.progress !== null ? Math.round(root.out.progress * 100) + "%" : ""
        }
        Sparkline {
            visible: root.template === "graph"
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; top: metric.bottom; topMargin: Tokens.gap * 0.5 }
            values: root.history
        }
        Column {
            visible: root.template === "list"
            width: parent.width
            Repeater {
                model: root.out ? root.out.items.slice(0, Math.max(1, Math.floor(area.height / (Tokens.textSize * 2.1)))) : []
                delegate: ListRow {
                    required property var modelData
                    title: typeof modelData === "object" ? modelData.label : modelData
                    trailing: typeof modelData === "object" ? modelData.value : ""
                }
            }
        }
        Label {
            visible: root.template === "text"
            anchors.fill: parent
            text: root.out ? [root.out.value, root.out.subtitle].concat(root.out.items.map(i => typeof i === "object" ? i.label + "  " + i.value : i)).filter(x => x).join("\n") : ""
            wrapMode: Text.WordWrap
            verticalAlignment: Text.AlignTop
            elide: Text.ElideRight
        }
    }
    // The last good output stays; a failure since then says so, dimly.
    Label {
        id: errLine
        visible: !!root.out && root.err.length > 0
        height: visible ? implicitHeight : 0
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        text: root.err; role: "danger"; size: Tokens.textSmall
    }
}
