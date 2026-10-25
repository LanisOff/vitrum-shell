import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components

/*
 * The time in other places.
 *   S   the first zone: its time big, the city and how far it is from here under it
 *   M   the header; a row per zone (city, the day and offset, the time)
 *   L   as M, roomier, each row led by a sun or a moon for day or night there
 * options: zones (IANA names), hours ("24" | "12").
 *
 * QML's JavaScript has no Intl, so toLocaleTimeString ignores timeZone and
 * says the local time. Each zone's UTC offset comes from `date` instead
 * (read-only), again every hour for the daylight-saving switches; the clock
 * itself is then plain arithmetic on the UTC time.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    readonly property var zones: (options.zones || []).map(z => String(z).trim()).filter(z => z.length > 0)
    // "auto" (and widgets saved before it existed) follow clock.h24 from Date & time.
    readonly property bool h12: options.hours === "12" || (options.hours !== "24" && !Settings.get("clock.h24", true))
    property date now: new Date()
    /// zone → offset from UTC in minutes, or null for a name the system does not know.
    property var offsets: ({})

    Timer { interval: 15000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }
    Timer { interval: 3600 * 1000; running: true; repeat: true; onTriggered: root.lookUp() }
    // Later, not inside whatever binding read `zones` first: lookUp() writes offsets, which `rows` reads.
    onZonesChanged: Qt.callLater(lookUp)
    Component.onCompleted: lookUp()

    // One look-up at a time; a change of zones while one runs asks again after it.
    property bool pending: false
    function lookUp() {
        if (!zones.length) { offsets = {}; return; }
        pending = true;
        if (!probe.running) kick();
    }
    function kick() {
        pending = false;
        probe.command = ["sh", "-c", probe.script, "sh"].concat(zones);
        probe.running = true;
    }
    Process {
        id: probe
        onRunningChanged: if (!running && root.pending) Qt.callLater(root.kick)
        // A name is a zone when its file exists (glibc quietly takes an unknown TZ as UTC).
        readonly property string script: 'for z; do case "$z" in *..*|/*) echo "$z ?"; continue;; esac; ' +
            'if [ -f "/usr/share/zoneinfo/$z" ]; then echo "$z $(TZ="$z" date +%z)"; else echo "$z ?"; fi; done'
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                for (const line of text.split("\n")) {
                    const m = line.match(/^(\S+) ([+-])(\d\d)(\d\d)$/);
                    if (m) out[m[1]] = (m[2] === "-" ? -1 : 1) * (Number(m[3]) * 60 + Number(m[4]));
                    else if (/^\S+ \?$/.test(line)) out[line.split(" ")[0]] = null;
                }
                root.offsets = out;
            }
        }
    }

    function pad(n) { return (n < 10 ? "0" : "") + n; }
    function city(zone) { const p = zone.split("/"); return p[p.length - 1].replace(/_/g, " "); }
    // How a zone's time stands against ours: "Tomorrow, +8 h", "−5 h", "Same time".
    function relation(zoneDate, diffMin) {
        const z = Date.UTC(zoneDate.getUTCFullYear(), zoneDate.getUTCMonth(), zoneDate.getUTCDate());
        const l = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate());
        const days = Math.round((z - l) / 86400000);
        const a = Math.abs(diffMin);
        const h = diffMin === 0 ? "" : (diffMin > 0 ? "+" : "−") + Math.floor(a / 60) + (a % 60 ? ":" + pad(a % 60) : "") + " h";
        const day = days > 0 ? "Tomorrow" : days < 0 ? "Yesterday" : "";
        return day && h ? day + ", " + h : day || h || "Same time";
    }
    /// { zone, city, ok, known, time, ampm, rel, day } for one zone, at `now`.
    function info(zone) {
        const off = offsets[zone];
        const known = off !== undefined;
        const base = { zone: zone, city: city(zone), ok: false, known: known, time: known ? "—" : "--:--", ampm: "", rel: known ? "Unknown zone" : "", day: true };
        if (off === null || off === undefined) return base;
        // The zone's wall clock, read off the UTC fields of a shifted instant.
        const d = new Date(now.getTime() + off * 60000);
        const hh = d.getUTCHours(), mm = d.getUTCMinutes();
        const shown = h12 ? ((hh % 12) || 12) + ":" + pad(mm) : pad(hh) + ":" + pad(mm);
        return { zone: zone, city: base.city, ok: true, known: true, time: shown, ampm: h12 ? (hh < 12 ? "AM" : "PM") : "",
                 rel: relation(d, off + now.getTimezoneOffset()), day: hh >= 6 && hh < 18 };
    }
    readonly property var rows: { now; offsets; h12; return zones.map(z => info(z)); }

    WidgetHeader {
        id: head
        visible: root.sizeClass !== "S"
        height: visible ? implicitHeight : 0
        icon: "world"; title: "World clocks"
        trailing: Qt.formatTime(root.now, root.h12 ? "h:mm AP" : "HH:mm") + " here"
    }
    WidgetEmpty {
        visible: root.zones.length === 0
        icon: "world"
        text: "Add time zones in the editor"
    }

    // ---- S: the first zone.
    Column {
        visible: root.sizeClass === "S" && root.rows.length > 0
        anchors.centerIn: parent
        width: root.width
        spacing: 2
        readonly property var r: root.rows.length ? root.rows[0] : null
        Metric {
            anchors.horizontalCenter: parent.horizontalCenter
            value: parent.r ? parent.r.time : ""
            unit: parent.r ? parent.r.ampm : ""
            size: Math.round(Math.min(root.height * 0.3, root.width / (root.h12 ? 4.2 : 3.2)))
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: parent.r ? parent.r.city : ""
            font.weight: Font.Medium
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: parent.r ? parent.r.rel : ""
            role: "dim"; size: Tokens.textSmall
        }
    }

    // ---- M and L: a row per zone, as many as fit.
    Column {
        id: list
        visible: root.sizeClass !== "S" && root.rows.length > 0
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: Tokens.gap * 0.5; bottom: parent.bottom }
        readonly property bool roomy: root.sizeClass !== "M"
        readonly property real minRow: Tokens.textSize * (roomy ? 3.0 : 2.5)
        readonly property int fits: Math.max(1, Math.floor(height / minRow))
        readonly property int shown: Math.min(root.rows.length, fits)
        // Rows share the height, but no taller than a comfortable list row.
        readonly property real rowH: Math.min(height / Math.max(1, shown), Tokens.textSize * (roomy ? 4.2 : 3.2))
        Repeater {
            model: root.rows.slice(0, list.shown)
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: list.width; height: list.rowH
                Rectangle {
                    visible: row.index > 0
                    width: parent.width; height: Tokens.hairline
                    color: Colors.alpha(Colors.text, 0.08)
                }
                Rectangle {
                    id: lead
                    visible: list.roomy
                    width: visible ? Math.round(Math.min(row.height * 0.62, Tokens.iconSize * 1.9)) : 0; height: width; radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: Colors.alpha(row.modelData.day ? Colors.meaning(0.12) : Colors.ink(40), Colors.dark ? 0.2 : 0.16)
                    Icon {
                        anchors.centerIn: parent
                        name: row.modelData.day ? "sun" : "moon"
                        size: Math.round(parent.width * 0.58)
                        filled: true
                        color: row.modelData.ok ? (row.modelData.day ? Colors.meaning(0.12) : Colors.ink(40)) : Colors.textDim
                    }
                }
                Column {
                    anchors { left: lead.right; leftMargin: list.roomy ? Tokens.gap * 0.8 : 0; right: clock.left; rightMargin: Tokens.gap * 0.5; verticalCenter: parent.verticalCenter }
                    Label { width: parent.width; text: row.modelData.city; font.weight: Font.Medium; role: row.modelData.ok ? "text" : "dim" }
                    Label { width: parent.width; visible: text.length > 0; text: row.modelData.rel; role: "dim"; size: Tokens.textSmall }
                }
                Metric {
                    id: clock
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    value: row.modelData.time
                    unit: row.modelData.ampm
                    size: Math.round(Math.min(row.height * 0.6, list.roomy ? Tokens.textTitle * 1.5 : Tokens.textTitle * 1.15))
                    color: row.modelData.ok ? Colors.text : Colors.textDim
                }
            }
        }
    }
}
