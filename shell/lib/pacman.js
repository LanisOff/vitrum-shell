.pragma library
// pacman, read for the bar: the transaction running now (from
// /var/log/pacman.log, readable by everyone) and the updates waiting (from
// `checkupdates` or `pacman -Qu`). The shape matches emerge.js, so the bar and
// the updates panel show either the same way.

function _time(stamp) {
    // "2026-10-04T10:00:00+0300" → seconds (Date wants "+03:00").
    var iso = String(stamp).replace(/([+-]\d\d)(\d\d)$/, "$1:$2");
    var t = Date.parse(iso);
    return isNaN(t) ? 0 : t / 1000;
}

// The last transaction in the log → { running, ok, done, total, current, since, started, failed }.
function parseLog(text) {
    var lines = String(text || "").split("\n");
    var s = { running: false, ok: true, done: 0, total: 0, current: "", since: 0, started: 0, failed: "" };
    for (var i = 0; i < lines.length; i++) {
        var m = /^\[([^\]]+)\]\s+\[ALPM\]\s+(.*)$/.exec(lines[i]);
        if (!m) continue;
        var t = _time(m[1]), msg = m[2], p;
        if (msg === "transaction started") {
            s = { running: true, ok: true, done: 0, total: 0, current: "", since: t, started: t, failed: "" };
        } else if ((p = /^(upgraded|installed|reinstalled|downgraded|removed)\s+(\S+)\s+\(/.exec(msg))) {
            s.done++; s.current = p[2]; s.since = t;
            if (!s.started) s.started = t;
        } else if (msg === "transaction completed") {
            s.running = false; s.ok = true;
        } else if (msg === "transaction failed" || msg === "transaction interrupted") {
            s.running = false; s.ok = false; s.failed = s.current;
        }
    }
    return s;
}

// "name old -> new" lines → [{ atom, from, to, kind: "update" }]
function parseUpdates(text) {
    var out = [];
    String(text || "").split("\n").forEach(function (l) {
        var m = /^(\S+)\s+(\S+)\s+->\s+(\S+)\s*$/.exec(l.trim());
        if (m) out.push({ atom: m[1], from: m[2], to: m[3], kind: "update" });
    });
    return out;
}
