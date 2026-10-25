.pragma library
// The screenshots widget: the capture folder's newest pictures, and when each was taken.

// find's "<mtime seconds>\t<path>" lines → [{ path, time (ms) }], newest first, at most `limit`.
function parseList(text, limit) {
    var out = [], lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var tab = lines[i].indexOf("\t");
        if (tab <= 0) continue;
        var t = parseFloat(lines[i].slice(0, tab)), p = lines[i].slice(tab + 1);
        if (!isFinite(t) || p.charAt(0) !== "/") continue;
        out.push({ path: p, time: Math.round(t * 1000) });
    }
    out.sort(function (a, b) { return b.time - a.time || (a.path < b.path ? -1 : 1); });
    return limit === undefined ? out : out.slice(0, limit);
}

// A file URL that survives "#", "?" and spaces in a name.
function fileUrl(path) { return "file://" + String(path).split("/").map(encodeURIComponent).join("/"); }

function _pad(n) { return (n < 10 ? "0" : "") + n; }
function _clock(d, h24) {
    if (h24) return _pad(d.getHours()) + ":" + _pad(d.getMinutes());
    var h = d.getHours() % 12 || 12;
    return h + ":" + _pad(d.getMinutes()) + (d.getHours() < 12 ? " AM" : " PM");
}
var _DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
var _MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
// When, as short as it reads: "14:05" today, "Yesterday", "Tue" this week, "3 Oct" before.
function when(ms, nowMs, h24) {
    var d = new Date(ms), n = new Date(nowMs);
    var day0 = new Date(n.getFullYear(), n.getMonth(), n.getDate()).getTime();
    if (ms >= day0) return _clock(d, h24);
    if (ms >= day0 - 86400000) return "Yesterday";
    if (ms >= day0 - 6 * 86400000) return _DAYS[d.getDay()];
    return d.getDate() + " " + _MONTHS[d.getMonth()] + (d.getFullYear() !== n.getFullYear() ? " " + d.getFullYear() : "");
}
