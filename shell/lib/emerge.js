.pragma library
// Portage, read for the bar: the build running now (from /var/log/emerge.log)
// and the updates waiting (from `emerge -puDN @world`).

// The last run in the log → { running, ok, done, total, current, since, started, failed }.
function parseLog(text) {
    var lines = String(text || "").split("\n");
    var s = { running: false, ok: true, done: 0, total: 0, current: "", since: 0, started: 0, failed: "" };
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i], m = /^(\d+):\s+(.*)$/.exec(l);
        if (!m) continue;
        var t = parseInt(m[1], 10), msg = m[2];
        if (/^Started emerge on:/.test(msg)) {
            s = { running: true, ok: true, done: 0, total: 0, current: "", since: t, started: t, failed: "" };
        } else if ((m = /^>>> emerge \((\d+) of (\d+)\) (\S+)/.exec(msg))) {
            s.running = true; s.total = parseInt(m[2], 10); s.current = m[3]; s.since = t;
            if (!s.started) s.started = t;
        } else if ((m = /^::: completed emerge \((\d+) of (\d+)\)/.exec(msg))) {
            s.done = parseInt(m[1], 10); s.total = parseInt(m[2], 10);
        } else if (/^\*\*\* exiting unsuccessfully/.test(msg)) {
            s.ok = false; s.failed = s.current; s.running = false;
        } else if (/^\*\*\* exiting successfully/.test(msg)) {
            s.ok = true; s.running = false;
        } else if (/^\*\*\* terminating\./.test(msg)) {
            s.running = false;
        }
    }
    return s;
}

// Seconds left, or -1 while there is nothing to average yet.
function eta(s, now) {
    if (!s.running || s.done < 1 || s.total <= s.done) return -1;
    var per = (s.since - s.started) / s.done;
    if (!(per > 0)) return -1;
    return Math.max(0, Math.round(per * (s.total - s.done) - (now - s.since)));
}

function formatEta(sec) {
    if (sec < 0) return "";
    var m = Math.ceil(sec / 60);
    return m >= 60 ? "~" + Math.floor(m / 60) + " h " + (m % 60) + " min" : "~" + m + " min";
}

// `emerge -puDN @world` → [{ atom, to, from, kind: "update" | "new" }]; rebuilds are left out.
function parseUpdates(text) {
    var out = [];
    String(text || "").split("\n").forEach(function (l) {
        var m = /^\[ebuild\s+([^\]]*)\]\s+(\S+?)-(\d[^\s:]*)(?:::\S+)?(?:\s+\[([^\]:]+)(?:::[^\]]*)?\])?/.exec(l);
        if (!m) return;
        var flags = m[1];
        var kind = /U/.test(flags) ? "update" : /N/.test(flags) ? "new" : "";
        if (!kind) return;
        var e = { atom: m[2], to: m[3], kind: kind };
        if (m[4]) e = { atom: m[2], to: m[3], from: m[4], kind: kind };
        out.push(e);
    });
    return out;
}
