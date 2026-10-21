.pragma library
// xbps (Void), read for the bar: the updates waiting, from `xbps-install -Mun`
// (the repositories synced into memory only, so no root is needed), and the
// run going on now. xbps keeps no log to follow, so a run is only "running"
// or "ended", and how it ended comes from the exit code the update command
// leaves behind. The shape matches emerge.js and pacman.js, so the bar and the
// updates panel show any of them the same way.

// "name-1.2_1" → { name, version }. xbps versions always end in _revision and
// never contain a dash, so the last dash splits them.
function splitPkgver(pkgver) {
    var s = String(pkgver || ""), i = s.lastIndexOf("-");
    if (i <= 0 || !/_\d+$/.test(s)) return null;
    return { name: s.slice(0, i), version: s.slice(i + 1) };
}

// `xbps-query -l` ("ii name-1.2_1  description") → { name: version }.
function parseInstalled(text) {
    var out = {};
    String(text || "").split("\n").forEach(function (l) {
        var m = /^\S\S\s+(\S+)/.exec(l);
        var p = m && splitPkgver(m[1]);
        if (p) out[p.name] = p.version;
    });
    return out;
}

// `xbps-install -un` lines ("name-1.2_1 update x86_64 https://repo… 123 456")
// → [{ atom, from, to, kind: "update" | "new" }]. `installed` (the text of
// `xbps-query -l`, optional) gives the version an update replaces. Anything
// else the transaction would do (remove, configure, hold) is left out, as
// emerge.js leaves out rebuilds.
function parseUpdates(text, installed) {
    var have = parseInstalled(installed), out = [];
    String(text || "").split("\n").forEach(function (l) {
        var m = /^(\S+)\s+(update|install)\s+\S+\s+\S+/.exec(l.trim());
        var p = m && splitPkgver(m[1]);
        if (!p) return;
        var e = { atom: p.name, to: p.version, kind: m[2] === "update" ? "update" : "new" };
        if (e.kind === "update" && have[p.name]) e = { atom: p.name, from: have[p.name], to: p.version, kind: "update" };
        out.push(e);
    });
    return out;
}

// xbps-install exits 0 even when no repository could be opened (offline): it
// only says so on stderr. Such a check found nothing, rather than found
// everything up to date.
function checkFailed(text) {
    return /^ERROR: /m.test(String(text || ""));
}

// The run, without a log, and only ours: the update command (Packages.update)
// writes "started PID" (its shell's) to a file as it begins and replaces it
// with its exit code when done. Root's other runs of the tool (dnf makecache
// on a timer, dnf5 automatic) leave no such file and are not shown: one
// could otherwise end as "Update finished" and set off a power off planned
// for after the update.
//   mark    the file's first word: "started", an exit code, or "" (no file)
//   alive   the PID it names still runs
// "started" with that shell gone: the run was cut off (its window closed),
// and that is a failure — a power off waiting for it must not go ahead.
// → { running, ok, done, total, current, since, started, failed, interrupted }
function runState(prev, mark, alive, now) {
    var p = prev || {}, m = String(mark === undefined || mark === null ? "" : mark).trim();
    var idle = { running: false, ok: true, done: 0, total: 0, current: "", since: 0, started: 0, failed: "" };
    if (m === "started" && alive) {
        if (p.running) return p;
        return { running: true, ok: true, done: 0, total: 0, current: "", since: now, started: now, failed: "" };
    }
    if (!p.running) return p.started !== undefined ? p : idle;
    var end = { running: false, ok: false, done: p.done || 0, total: p.total || 0, current: p.current || "", since: now, started: p.started || 0, failed: "" };
    if (/^\d+$/.test(m)) { end.ok = m === "0"; return end; }
    end.interrupted = true;          // "started" with nobody left, or the file gone
    return end;
}
