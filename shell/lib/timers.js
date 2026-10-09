.pragma library
// Timers and pomodoro: what "5m" means, how the countdown reads, which phase comes next.

var UNIT = { s: 1, sec: 1, secs: 1, second: 1, seconds: 1, "с": 1, "сек": 1, "секунд": 1, "секунды": 1,
             m: 60, min: 60, mins: 60, minute: 60, minutes: 60, "м": 60, "мин": 60, "минут": 60, "минуты": 60, "минута": 60,
             h: 3600, hr: 3600, hour: 3600, hours: 3600, "ч": 3600, "час": 3600, "часа": 3600, "часов": 3600 };

// "5m", "1h30m", "timer 10 min", "10 минут" → seconds; null when it is not a duration.
function parse(q) {
    var s = String(q || "").toLowerCase().trim().replace(/^(timer|таймер)\s+/, "");
    var re = /(\d+(?:[.,]\d+)?)\s*([a-zа-я]+)/g, m, total = 0;
    if (!s || s.replace(re, "").trim().length) return null;     // anything besides "<n><unit>" pairs
    re.lastIndex = 0;
    while ((m = re.exec(s)) !== null) {
        var u = UNIT[m[2]];
        if (!u) return null;
        total += parseFloat(m[1].replace(",", ".")) * u;
    }
    total = Math.round(total);
    return total > 0 ? total : null;
}

function _pad(n) { return (n < 10 ? "0" : "") + n; }

// Seconds left → "4:59" (rounded up, so it never reads 0:00 while running).
function format(left) {
    var s = Math.max(0, Math.ceil(left - 1e-6));
    var h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, sec = s % 60;
    return h ? h + ":" + _pad(m) + ":" + _pad(sec) : m + ":" + _pad(sec);
}

function label(seconds) {
    var h = Math.floor(seconds / 3600), m = Math.floor(seconds / 60) % 60, s = seconds % 60;
    if (!h && !s) return m + "-minute timer";
    var parts = [];
    if (h) parts.push(h + " h");
    if (m) parts.push(m + " min");
    if (s) parts.push(s + " s");
    return parts.join(" ") + " timer";
}

// The phase after `cur` ({phase, round}), with its length; null starts a session.
// p: { work, short, long (minutes), rounds }
function pomodoroNext(cur, p) {
    if (!cur || cur.phase === "long") return { phase: "work", round: 1, seconds: p.work * 60 };
    if (cur.phase === "work")
        return cur.round >= p.rounds ? { phase: "long", round: cur.round, seconds: p.long * 60 }
                                     : { phase: "break", round: cur.round, seconds: p.short * 60 };
    return { phase: "work", round: cur.round + 1, seconds: p.work * 60 };
}
