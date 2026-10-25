.pragma library
// The stopwatch, as timestamps: nothing counts while it runs, the time is
// worked out from them whenever it is shown (so it keeps going while hidden,
// through a restart of the shell too, kept in the widget's options).
//   since  when it was last started (ms since the epoch), 0 while stopped
//   acc    the time run before that (ms)
//   laps   the total at each lap, as strings of ms, oldest first

function elapsed(s, now) {
    var acc = Math.max(0, Number(s.acc) || 0), since = Number(s.since) || 0;
    return acc + (since > 0 ? Math.max(0, now - since) : 0);
}
function running(s) { return (Number(s.since) || 0) > 0; }

function start(s, now) { return running(s) ? s : { since: Math.max(1, now), acc: Number(s.acc) || 0, laps: (s.laps || []).slice() }; }
function pause(s, now) { return running(s) ? { since: 0, acc: elapsed(s, now), laps: (s.laps || []).slice() } : s; }
function lap(s, now) {
    var t = Math.round(elapsed(s, now));
    return { since: Number(s.since) || 0, acc: Number(s.acc) || 0, laps: (s.laps || []).concat([String(t)]).slice(-99) };
}
function reset() { return { since: 0, acc: 0, laps: [] }; }

// The laps, newest first: [{ n, split, total, best, worst }] (best and worst
// only once there are three, so two laps are not "the worst" of each other).
function laps(s) {
    var tot = (s.laps || []).map(Number).filter(function (x) { return isFinite(x) && x >= 0; });
    var out = [], prev = 0, i;
    for (i = 0; i < tot.length; i++) { out.push({ n: i + 1, split: Math.max(0, tot[i] - prev), total: tot[i], best: false, worst: false }); prev = tot[i]; }
    if (out.length >= 3) {
        var lo = 0, hi = 0;
        for (i = 1; i < out.length; i++) { if (out[i].split < out[lo].split) lo = i; if (out[i].split > out[hi].split) hi = i; }
        out[lo].best = true; out[hi].worst = true;
    }
    return out.reverse();
}

function _p2(n) { return n < 10 ? "0" + n : String(n); }
// 0:07.4 · 12:34.5 · 1:02:03 (no tenths past an hour); tenths: false drops them.
function format(ms, tenths) {
    var t = Math.max(0, Math.floor(ms / 100));
    var d = t % 10, sec = Math.floor(t / 10), s = sec % 60, m = Math.floor(sec / 60) % 60, h = Math.floor(sec / 3600);
    if (h > 0) return h + ":" + _p2(m) + ":" + _p2(s);
    return m + ":" + _p2(s) + (tenths === false ? "" : "." + d);
}
