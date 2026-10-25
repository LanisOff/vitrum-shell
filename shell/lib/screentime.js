.pragma library
// Screen time: how long each app had the focus, per day. `days` is
// { "YYYY-MM-DD": { appId: seconds } }, in local time; a stretch of focus that
// runs past midnight is split between the two days.

function _pad(n) { return (n < 10 ? "0" : "") + n; }
function dayKey(ms) {
    var d = new Date(ms);
    return d.getFullYear() + "-" + _pad(d.getMonth() + 1) + "-" + _pad(d.getDate());
}
function _nextMidnight(ms) {
    var d = new Date(ms);
    return new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1).getTime();
}

// `app` had the focus from `from` to `to` (ms). → a new days object: the days
// it touches are copied, the rest shared. Nothing for no app or no time.
function credit(days, app, from, to) {
    var out = {}, k;
    for (k in days || {}) out[k] = days[k];
    if (!app || !(to > from)) return out;
    var t = from;
    while (t < to) {
        var end = Math.min(to, _nextMidnight(t)), key = dayKey(t), day = {};
        for (k in out[key] || {}) day[k] = out[key][k];
        day[app] = Math.round(((day[app] || 0) + (end - t) / 1000) * 10) / 10;
        out[key] = day;
        t = end;
    }
    return out;
}

// Only the last `keep` days, today among them.
function prune(days, nowMs, keep) {
    var d = new Date(nowMs);
    var cutoff = dayKey(new Date(d.getFullYear(), d.getMonth(), d.getDate() - Math.max(1, keep) + 1).getTime());
    var out = {};
    for (var k in days || {}) if (k >= cutoff) out[k] = days[k];
    return out;
}

// What a file holds, made safe: day keys, app ids, finite seconds ≥ 0.
function sanitize(obj) {
    var src = obj && typeof obj === "object" && obj.days && typeof obj.days === "object" ? obj.days : {};
    var out = {};
    for (var k in src) {
        if (!/^\d{4}-\d\d-\d\d$/.test(k) || !src[k] || typeof src[k] !== "object") continue;
        var day = {};
        for (var a in src[k]) {
            var s = src[k][a];
            if (a && typeof s === "number" && isFinite(s) && s > 0) day[a] = s;
        }
        out[k] = day;
    }
    return out;
}

function total(day) {
    var t = 0;
    for (var a in day || {}) t += day[a];
    return t;
}

// The day's apps, most used first: [{ app, seconds }], the first `n`.
function ranked(day, n) {
    var out = [];
    for (var a in day || {}) if (day[a] >= 1) out.push({ app: a, seconds: day[a] });
    out.sort(function (x, y) { return y.seconds - x.seconds || (x.app < y.app ? -1 : 1); });
    return n === undefined ? out : out.slice(0, n);
}

// "2 h 05 min", "35 min", "< 1 min"; compact: "2h 05m", "35m", "<1m".
function duration(seconds, compact) {
    var m = Math.floor(Math.max(0, seconds || 0) / 60);
    if (m < 1) return compact ? "<1m" : "< 1 min";
    var h = Math.floor(m / 60), mm = m % 60;
    if (!h) return compact ? m + "m" : m + " min";
    if (compact) return h + "h " + _pad(mm) + "m";
    return mm ? h + " h " + _pad(mm) + " min" : h + " h";
}
