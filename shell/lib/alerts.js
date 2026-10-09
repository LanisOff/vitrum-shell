.pragma library
// Hardware alerts: when to say something (a condition that lasts, said once per
// cooldown), which disks are nearly full, what SMART says is wrong.

// state: { key: { since, last } }; over: the condition now; now/hold/cooldown in seconds.
// → { state, fire }
function watch(state, key, over, now, hold, cooldown) {
    var s = {}, k;
    for (k in state) s[k] = state[k];
    var e = s[key] ? { since: s[key].since, last: s[key].last } : { since: -1, last: -1e12 };
    var fire = false;
    if (!over) e.since = -1;
    else {
        if (e.since < 0) e.since = now;
        if (now - e.since >= hold && now - e.last >= cooldown) { fire = true; e.last = now; }
    }
    s[key] = e;
    return { state: s, fire: fire };
}

// `df -P -B1` → [{ mount, percent, freeGB }] of the ones over `percent`, or under
// `minFree` bytes — that floor only for disks big enough for it to mean
// something (four times the floor): a 1 GB /boot is fine with 600 MB free.
function fullDisks(text, percent, minFree) {
    var out = [];
    String(text || "").split("\n").slice(1).forEach(function (l) {
        var p = l.trim().split(/\s+/);
        if (p.length < 6) return;
        var size = +p[1], avail = +p[3], pct = parseInt(p[4], 10), mount = p.slice(5).join(" ");
        if (!(size > 0)) return;
        if (pct >= percent || (avail < minFree && size >= 4 * minFree))
            out.push({ mount: mount, percent: pct, freeGB: Math.round(avail / 1073741824 * 10) / 10 });
    });
    return out;
}

// `smartctl -H -A -j` (parsed) → "" when healthy, else what is wrong.
function smartProblem(j) {
    if (!j) return "";
    if (j.smart_status && j.smart_status.passed === false) return "the drive reports it is failing";
    var n = j.nvme_smart_health_information_log;
    if (n) {
        if (n.critical_warning) return "critical warning " + n.critical_warning;
        if (n.media_errors) return n.media_errors + " media errors";
    }
    var t = (j.ata_smart_attributes && j.ata_smart_attributes.table) || [];
    for (var i = 0; i < t.length; i++) {
        var raw = t[i].raw ? +t[i].raw.value : 0;
        if (t[i].id === 5 && raw > 0) return raw + " reallocated sectors";
        if (t[i].id === 197 && raw > 0) return raw + " sectors waiting to be reallocated";
    }
    return "";
}
