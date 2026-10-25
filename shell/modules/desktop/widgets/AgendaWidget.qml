import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import "../../../lib/agenda.js" as Lib

/*
 * The agenda: the coming events of the calendars in a folder of .ics files
 * (one file a calendar, or a folder a calendar as vdirsyncer keeps them, with
 * its `color` and `displayname`), repeats and time zones worked out by lib/agenda.js.
 *   S   the next event: its time big, its title, its calendar's dot and name,
 *       how many more today
 *   M   the header; the days (today, tomorrow…), each its events: the
 *       calendar's dot, the time, the title
 *   L   the same, with each event's place under its title
 * Ended events are left out; a day with none says "Nothing planned".
 * The folder is read when it changes: a cheap signature (names, times, sizes)
 * every five minutes while the widget shows, the files only when it differs.
 * options: folder, days (how many days, today the first), allDay.
 * In a gallery card a sample day stands in; nothing is read.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    readonly property string folder: {
        const f = String(options.folder || "~/.local/share/vitrum/calendars");
        const home = Quickshell.env("HOME") || "";
        return f === "~" ? home : f.indexOf("~/") === 0 ? home + f.slice(1) : f;
    }
    readonly property int days: Math.max(1, Math.min(14, Number(options.days) || 2))
    readonly property bool allDay: options.allDay !== false
    readonly property bool h24: Settings.get("clock.h24", true)

    property date now: new Date()
    readonly property real dayStart: new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
    // The minute only filters out what has ended; the day moves the window.
    Timer {
        interval: 60000; repeat: true; triggeredOnStart: true
        running: !root.preview && root.visible && !GameMode.active
        onTriggered: root.now = new Date()
    }

    // ------------------------------------------------------------ reading ---
    property string sig: ""
    property bool read: false          // the folder has been looked at
    property bool exists: false
    property var cals: []
    // The window's occurrences: worked out again when the calendars, the day
    // or the number of days change, not every minute.
    readonly property var occ: preview || !cals.length ? [] : Lib.occurrences(cals, dayStart, dayStart + (days + 1) * 86400000)
    Process {
        id: reader
        command: ["sh", "-c", root.script, "_", root.folder, root.sig]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = Lib.splitDump(text);
                root.read = true;
                root.exists = d.sig !== "none" && d.sig !== "";
                if (d.sig === root.sig && root.exists) return;      // unchanged: nothing sent
                root.sig = d.sig;
                root.cals = root.exists ? Lib.parseAll(d.calendars) : [];
            }
        }
    }
    readonly property string script: "d=\"$1\"; [ -d \"$d\" ] || { printf '\\036SIG none\\n'; exit 0; }\n"
        + "sig=$(find -L \"$d\" -maxdepth 3 \\( -name '*.ics' -o -name color -o -name displayname \\) -type f -exec stat -c '%n %Y %s' {} + 2>/dev/null | sort | cksum)\n"
        + "printf '\\036SIG %s\\n' \"$sig\"; [ \"$sig\" = \"$2\" ] && exit 0\n"
        + "{ for f in \"$d\"/*.ics; do [ -f \"$f\" ] || continue; printf '\\036CAL %s\\n' \"$f\"; cat \"$f\"; printf '\\n'; done\n"
        + "  for c in \"$d\"/*/; do [ -d \"$c\" ] || continue; c=${c%/}; printf '\\036CAL %s\\n' \"$c\"\n"
        + "    [ -f \"$c/color\" ] && printf '\\036META color %s\\n' \"$(head -c 64 \"$c/color\" | tr -d '\\n')\"\n"
        + "    [ -f \"$c/displayname\" ] && printf '\\036META name %s\\n' \"$(head -c 200 \"$c/displayname\" | tr -d '\\n')\"\n"
        + "    find -L \"$c\" -maxdepth 2 -name '*.ics' -type f -exec cat {} + 2>/dev/null; printf '\\n'\n"
        + "  done; } | head -c 16000000\n"
    // Deferred: the host sets options, then preview, right after this item is
    // made, and a gallery card must not read anything.
    function reread() { Qt.callLater(_reread); }
    property bool _again: false
    function _reread() {
        if (preview) return;
        if (reader.running) { _again = true; return; }
        reader.running = true;
    }
    Connections {
        target: reader
        function onRunningChanged() { if (!reader.running && root._again) { root._again = false; root._reread(); } }
    }
    onFolderChanged: { sig = ""; read = false; reread(); }
    // From the start, and at once again when it shows after a while hidden
    // (after a game, say): the timer fires as it starts.
    Timer {
        interval: 5 * 60 * 1000; repeat: true; triggeredOnStart: true
        running: !root.preview && root.visible && !GameMode.active
        onTriggered: root.reread()
    }

    // -------------------------------------------------------------- sample ---
    readonly property var sampleCals: [{ name: "Work", color: "", hue: 0 }, { name: "Home", color: "", hue: 120 }, { name: "Family", color: "", hue: 240 }]
    readonly property var sampleOcc: {
        const t = new Date(2026, 9, 26), at = (d, h, m) => new Date(t.getFullYear(), t.getMonth(), t.getDate() + d, h, m).getTime();
        return [
            { title: "Design review", location: "Room 4", start: at(0, 10, 0), end: at(0, 11, 0), allDay: false, cal: 0 },
            { title: "Lunch with Sam", location: "Corner café", start: at(0, 13, 30), end: at(0, 14, 30), allDay: false, cal: 1 },
            { title: "Gym", location: "", start: at(0, 18, 0), end: at(0, 19, 0), allDay: false, cal: 1 },
            { title: "Mum's birthday", location: "", start: at(1, 0, 0), end: at(2, 0, 0), allDay: true, cal: 2 },
            { title: "Dentist", location: "Clinic, 2nd floor", start: at(1, 9, 30), end: at(1, 10, 15), allDay: false, cal: 1 },
            { title: "Sprint planning", location: "", start: at(1, 11, 0), end: at(1, 12, 0), allDay: false, cal: 0 }
        ];
    }
    readonly property var calList: preview ? sampleCals : cals
    readonly property var agenda: preview ? Lib.agenda(sampleOcc, new Date(2026, 9, 26, 9, 12).getTime(), days, allDay)
                                          : Lib.agenda(occ, now.getTime(), days, allDay)
    readonly property bool ready: preview || (read && exists && cals.length > 0)
    readonly property int total: agenda.reduce((n, d) => n + d.items.length, 0)

    function calColor(i) {
        const c = calList[i];
        return c && c.color ? c.color : Colors.ink(c ? c.hue : 0);
    }
    function clock(ms) { return Qt.formatTime(new Date(ms), h24 ? "HH:mm" : "h:mm AP"); }
    function timeOf(it) {
        return it.kind === "start" ? clock(it.at) : it.kind === "until" ? "till " + clock(it.at) : "All day";
    }
    function dayName(d, i) {
        if (i === 0) return "Today";
        if (i === 1) return "Tomorrow";
        return Qt.formatDate(new Date(d.start), "dddd d MMMM");
    }
    // The days and their events as one list: { day: label } rows, then { ev }.
    readonly property var flat: {
        const out = [];
        for (let i = 0; i < agenda.length; i++) {
            const d = agenda[i];
            out.push({ head: dayName(d, i), count: d.items.length, first: i === 0 });
            if (!d.items.length) out.push({ none: true });
            for (const it of d.items) out.push({ ev: it });
        }
        return out;
    }
    // The next thing on: today's first timed event still to come or under
    // way, else today's first all-day one, else the first of a later day.
    readonly property int nextDay: {
        for (let i = 0; i < agenda.length; i++) if (agenda[i].items.length) return i;
        return -1;
    }
    readonly property var next: {
        if (nextDay < 0) return null;
        const items = agenda[nextDay].items;
        return items.find(it => !it.allDay) || items[0];
    }
    readonly property int moreToday: nextDay === 0 ? agenda[0].items.length - 1 : 0

    WidgetHeader {
        id: head
        visible: root.sizeClass !== "S"
        height: visible ? implicitHeight : 0
        icon: "event"; title: "Agenda"
        trailing: root.ready && root.agenda.length ? (root.agenda[0].items.length ? root.agenda[0].items.length + " today" : "Free today") : ""
    }
    WidgetEmpty {
        visible: !root.ready && (root.read || root.preview)
        icon: "event"
        text: !root.exists ? "Put .ics files or synced calendars in " + (root.options.folder || "~/.local/share/vitrum/calendars")
                           : "No calendars in " + (root.options.folder || "~/.local/share/vitrum/calendars")
    }
    WidgetEmpty {
        visible: root.ready && root.total === 0
        icon: "event"
        text: "Nothing planned"
    }

    // ---- S: the next one.
    Column {
        visible: root.ready && root.sizeClass === "S" && !!root.next
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 2
        Label {
            text: root.nextDay <= 0 ? "Next" : root.nextDay === 1 ? "Tomorrow" : Qt.formatDate(new Date(root.agenda[root.nextDay].start), "dddd")
            role: "dim"; size: Tokens.textSmall
        }
        Label {
            width: parent.width
            text: root.next ? root.timeOf(root.next) : ""
            numeric: true
            font.weight: Font.Light
            size: Math.round(root.height * 0.2)
        }
        Label {
            width: parent.width
            text: root.next ? root.next.title : ""
            font.weight: Font.Medium
            wrapMode: Text.WordWrap; maximumLineCount: 2
        }
        Row {
            spacing: Tokens.gap * 0.4
            width: parent.width
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(Tokens.textSmall * 0.6); height: width; radius: width / 2
                color: root.next ? root.calColor(root.next.cal) : "transparent"
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Tokens.textSmall
                text: root.next && root.calList[root.next.cal] ? root.calList[root.next.cal].name + (root.moreToday ? " · +" + root.moreToday + " more" : "") : ""
                role: "dim"; size: Tokens.textSmall
            }
        }
    }

    // ---- M and L: the days.
    ListView {
        id: list
        visible: root.ready && root.sizeClass !== "S" && root.total > 0
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; topMargin: Tokens.gap * 0.2 }
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.flat
        readonly property bool big: root.sizeClass === "L" || root.sizeClass === "XL"
        // As wide as the widest time it can hold, the dot and a gap before it.
        readonly property real timeW: Math.ceil(Math.max(widest.width, allDayText.width, tillText.width) + Tokens.textSmall * 0.6 + Tokens.gap * 1.2)
        TextMetrics { id: widest; font.family: Tokens.fontText; font.pixelSize: Tokens.textSmall + 1; font.features: ({ "tnum": 1 }); text: root.h24 ? "00:00" : "12:00 PM" }
        TextMetrics { id: allDayText; font.family: Tokens.fontText; font.pixelSize: Tokens.textSmall + 1; text: "All day" }
        TextMetrics { id: tillText; font.family: Tokens.fontText; font.pixelSize: Tokens.textSmall + 1; font.features: ({ "tnum": 1 }); text: root.h24 ? "till 00:00" : "till 12:00 PM" }
        delegate: Item {
            id: row
            required property var modelData
            width: list.width
            height: modelData.head !== undefined ? Math.round(Tokens.textSmall * (modelData.first ? 1.6 : 2.2))
                  : modelData.none ? Math.round(Tokens.textSize * 1.6)
                  : Math.round(Tokens.textSize * (list.big && modelData.ev.location ? 2.6 : 1.75))
            // A day's name, small and dim, a hairline over all but the first.
            Rectangle {
                visible: row.modelData.head !== undefined && !row.modelData.first
                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: Math.round(Tokens.textSmall * 0.3) }
                height: Tokens.hairline
                color: Colors.alpha(Colors.text, 0.1)
            }
            Label {
                visible: row.modelData.head !== undefined
                anchors { left: parent.left; bottom: parent.bottom }
                text: row.modelData.head || ""
                role: "dim"; size: Tokens.textSmall
                font.weight: Font.Medium
            }
            Label {
                visible: !!row.modelData.none
                anchors { left: parent.left; leftMargin: list.timeW; verticalCenter: parent.verticalCenter }
                text: "Nothing planned"
                role: "dim"; size: Tokens.textSmall
            }
            // An event: the dot, the time, the title (and the place, at L).
            Item {
                visible: !!row.modelData.ev
                anchors.fill: parent
                readonly property var ev: row.modelData.ev || ({})
                Rectangle {
                    id: dot
                    x: 1
                    y: Math.round(Tokens.textSize * 0.875 - height / 2)
                    width: Math.round(Tokens.textSmall * 0.6); height: width; radius: width / 2
                    color: row.modelData.ev ? root.calColor(parent.ev.cal) : "transparent"
                }
                Label {
                    x: dot.width + Tokens.gap * 0.5
                    width: list.timeW - x - Tokens.gap * 0.4
                    height: Math.round(Tokens.textSize * 1.75)
                    text: row.modelData.ev ? root.timeOf(parent.ev) : ""
                    numeric: true
                    role: parent.ev.kind === "start" ? "text" : "dim"
                    size: Tokens.textSmall + 1
                }
                Label {
                    id: title
                    x: list.timeW
                    width: parent.width - x
                    height: Math.round(Tokens.textSize * 1.75)
                    text: parent.ev.title || ""
                }
                Label {
                    visible: list.big && !!parent.ev.location
                    x: list.timeW
                    y: title.height - Math.round(Tokens.textSize * 0.25)
                    width: parent.width - x
                    text: parent.ev.location || ""
                    role: "dim"; size: Tokens.textSmall
                }
            }
        }
    }
}
