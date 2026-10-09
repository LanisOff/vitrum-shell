.pragma library
// The calendar panel's arithmetic: quick entry, a day's events, reminders.

function _pad(n) { return (n < 10 ? "0" : "") + n; }
function ymd(d) { return d.getFullYear() + "-" + _pad(d.getMonth() + 1) + "-" + _pad(d.getDate()); }

// "14:30 Dentist 30m" → { title, time, minutes }; "Trip" → all day (time "").
function parseQuick(text) {
    var s = String(text || "").trim();
    if (!s) return null;
    var m = /^(\d{1,2}):(\d{2})\s+(.+)$/.exec(s);
    if (!m) return { title: s, time: "", minutes: 0 };
    var h = parseInt(m[1], 10), mi = parseInt(m[2], 10);
    if (h > 23 || mi > 59) return null;
    var rest = m[3], minutes = 60;
    var len = /\s+(\d+)\s*(m|min|h)$/i.exec(rest);
    if (len) { minutes = parseInt(len[1], 10) * (len[2].toLowerCase() === "h" ? 60 : 1); rest = rest.slice(0, len.index); }
    return { title: rest.trim(), time: _pad(h) + ":" + _pad(mi), minutes: minutes };
}

// Events on a day (several-day all-day events count on every day they span).
function on(events, day) {
    var k = ymd(day);
    return events.filter(function (e) {
        var s = e.start.slice(0, 10), en = (e.end || e.start).slice(0, 10);
        return e.allDay ? s <= k && k <= en : s === k;
    });
}

function _start(e) {
    var p = /^(\d{4})-(\d{2})-(\d{2})(?: (\d{2}):(\d{2}))?/.exec(e.start);
    if (!p) return null;
    return new Date(+p[1], +p[2] - 1, +p[3], +(p[4] || 0), +(p[5] || 0));
}
function timeOf(e) { return e.allDay ? "" : e.start.slice(11, 16); }

// Remind now? `minutes` before a timed event, within a minute's window.
function due(e, now, minutes) {
    if (e.allDay) return false;
    var s = _start(e);
    if (!s) return false;
    var left = (s.getTime() - now.getTime()) / 60000;
    return left <= minutes && left > minutes - 1;
}
