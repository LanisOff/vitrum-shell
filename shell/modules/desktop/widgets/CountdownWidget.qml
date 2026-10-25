import QtQuick
import qs.services
import qs.theme
import qs.components

/*
 * Days until a date.
 *   S   the days left big, "days to <title>" under them; under two days the
 *       hours and minutes; once it is past, the title and how long ago
 *   M   the header (the title, the date); the same beside the weekday and
 *       date; when the date is this year, how far the year has come toward it
 * options: title, date ("YYYY-MM-DD" or "YYYY-MM-DD HH:MM"), color.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "S"
    property bool preview: false
    signal optionsEdited(var options)

    readonly property string title: (options.title || "").trim() || "the day"
    readonly property color tint: !options.color || options.color === "accent" ? Colors.accent : Colors.ink(Number(options.color))

    property date now: new Date()
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }

    // → { at: Date, timed: bool } or null when it is not a real date.
    function parse(s) {
        const m = String(s || "").trim().match(/^(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2}):(\d{2}))?$/);
        if (!m) return null;
        const y = Number(m[1]), mo = Number(m[2]) - 1, d = Number(m[3]);
        const h = m[4] !== undefined ? Number(m[4]) : 0, mi = m[5] !== undefined ? Number(m[5]) : 0;
        if (h > 23 || mi > 59) return null;
        const at = new Date(y, mo, d, h, mi);
        // 2026-02-30 rolls over into March: not a date.
        if (at.getFullYear() !== y || at.getMonth() !== mo || at.getDate() !== d) return null;
        return { at: at, timed: m[4] !== undefined };
    }
    readonly property var target: parse(options.date)
    readonly property bool ok: target !== null

    function dayOf(d) { return Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()); }
    readonly property real msLeft: ok ? target.at.getTime() - now.getTime() : 0
    readonly property bool past: ok && msLeft <= 0
    readonly property bool soon: ok && !past && msLeft < 2 * 86400000
    /// Calendar days between today and the date (negative once it is behind).
    readonly property int days: ok ? Math.round((dayOf(target.at) - dayOf(now)) / 86400000) : 0

    readonly property string big: {
        if (!ok || past) return "";
        if (soon) {
            const m = Math.ceil(msLeft / 60000);
            return Math.floor(m / 60) + ":" + (m % 60 < 10 ? "0" : "") + (m % 60);
        }
        return String(days);
    }
    readonly property string caption: !ok ? ""
        : past ? (days === 0 ? "today" : "passed " + (-days) + (days === -1 ? " day ago" : " days ago"))
        : soon ? "until " + title
        : (days === 1 ? "day to " : "days to ") + title

    // How far the year has come from 1 January toward the date, while it lies this year.
    readonly property bool hasProgress: ok && !past && target.at.getFullYear() === now.getFullYear()
    readonly property real progress: {
        if (!hasProgress) return 0;
        const start = new Date(now.getFullYear(), 0, 1).getTime();
        return (now.getTime() - start) / Math.max(1, target.at.getTime() - start);
    }

    readonly property string dateText: ok ? Qt.formatDate(target.at, "dddd, d MMMM yyyy") + (target.timed ? ", " + Qt.formatTime(target.at, Settings.get("clock.h24", true) ? "HH:mm" : "h:mm AP") : "") : ""

    WidgetHeader {
        id: head
        visible: root.sizeClass !== "S"
        height: visible ? implicitHeight : 0
        icon: "countdown"; title: root.title.charAt(0).toUpperCase() + root.title.slice(1)
        tint: root.tint
        trailing: root.ok ? Qt.formatDate(root.target.at, "d MMM yyyy") : ""
    }
    WidgetEmpty {
        visible: !root.ok
        icon: "countdown"
        text: "Set a date in the editor"
    }

    // ---- S: one glance.
    Column {
        visible: root.ok && root.sizeClass === "S"
        anchors.centerIn: parent
        width: root.width
        spacing: 2
        Metric {
            visible: !root.past
            anchors.horizontalCenter: parent.horizontalCenter
            value: root.big
            size: Math.round(Math.min(root.height * 0.4, root.width / Math.max(2, root.big.length * 0.62)))
            color: root.tint
        }
        Label {
            visible: root.past
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: root.title
            size: Tokens.textTitle; font.weight: Font.Medium
            wrapMode: Text.WordWrap; maximumLineCount: 2
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: root.caption
            role: "dim"; size: Tokens.textSmall
            wrapMode: Text.WordWrap; maximumLineCount: 2
        }
    }

    // ---- M: the number beside the date, the year's progress along the bottom.
    Row {
        id: body
        visible: root.ok && root.sizeClass !== "S"
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: meter.visible ? meter.top : parent.bottom; bottomMargin: meter.visible ? Tokens.gap * 0.6 : 0 }
        spacing: Tokens.gap * 1.2
        Metric {
            id: num
            visible: !root.past
            anchors.verticalCenter: parent.verticalCenter
            value: root.big
            size: Math.round(Math.max(28, Math.min(body.height * 0.82, 64)))
            color: root.tint
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: body.width - (root.past ? 0 : num.width + body.spacing)
            Label { width: parent.width; text: root.past ? root.title : root.caption; font.weight: Font.Medium }
            Label { width: parent.width; text: root.past ? root.caption.charAt(0).toUpperCase() + root.caption.slice(1) : root.dateText; role: "dim"; size: Tokens.textSmall }
        }
    }
    Meter {
        id: meter
        group: "widgets"
        visible: root.ok && root.sizeClass !== "S" && root.hasProgress
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        value: root.progress
        color: root.tint
        label: "From 1 January"
        trailing: Math.round(root.progress * 100) + "%"
    }
}
