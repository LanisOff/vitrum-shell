.pragma library
// dnf (Fedora), read for the bar: the updates waiting, from `dnf check-update
// -q`, which dnf4 and dnf5 both answer without root (each in a cache of the
// user's own). The shape matches emerge.js, pacman.js and xbps.js. The run
// going on now is told like xbps's (xbps.js runState): dnf's log is for
// debugging, not for following a transaction.
//
// Both print "name.arch  [epoch:]version-release  repo", one package a line;
// dnf4 starts with an empty line, wraps a name too long for its column onto a
// line of its own, and ends with an "Obsoleting Packages" section whose
// indented lines are the installed packages being replaced.

// Architectures a package of another word size has; the rest (the machine's
// own, and noarch) are named without one.
var _foreign = { i686: 1, i586: 1, i386: 1, armv7hl: 1 };

// "python3.12.x86_64" → { name: "python3.12", arch: "x86_64" }: names have dots,
// the architecture never does.
function splitNameArch(s) {
    var i = String(s).lastIndexOf(".");
    if (i <= 0) return null;
    var arch = s.slice(i + 1);
    if (!/^[a-z0-9_]+$/.test(arch)) return null;
    return { name: s.slice(0, i), arch: arch };
}

function _atom(p) { return _foreign[p.arch] ? p.name + "." + p.arch : p.name; }

// `rpm -qa --qf '%{NAME}.%{ARCH} %|EPOCH?{%{EPOCH}:}:{}|%{VERSION}-%{RELEASE}\n'`
// → { "name.arch": "[epoch:]version-release" }, written as dnf writes versions
// (an rpm that prints the epoch even when it is 0 has it taken off).
function parseInstalled(text) {
    var out = {};
    String(text || "").split("\n").forEach(function (l) {
        var m = /^(\S+)\s+(\S+)\s*$/.exec(l.trim());
        if (m) out[m[1]] = m[2].replace(/^0:/, "");   // dnf leaves a zero epoch out
    });
    return out;
}

// dnf check-update output (dnf4 or dnf5) → [{ atom, from, to, kind }].
// `installed` (the rpm query above, optional) gives the version replaced.
// A package that only obsoletes another (a rename) is "new".
function parseUpdates(text, installed) {
    var have = parseInstalled(installed), out = [], seen = {};
    var lines = String(text || "").split("\n"), obsoleting = false;
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i];
        if (/^Obsoleting packages/i.test(l.trim())) { obsoleting = true; continue; }
        if (/^\s/.test(l) && l.trim()) continue;          // installed, being obsoleted
        var f = l.trim().split(/\s+/);
        // A name too long for dnf4's column: the rest is on the next line.
        if (f.length === 1 && f[0] && i + 1 < lines.length && /^\s+\S+\s+\S+\s*$/.test(lines[i + 1])) {
            f = f.concat(lines[++i].trim().split(/\s+/));
        }
        if (f.length !== 3 || !/^(\d+:)?[^\s:-][^\s:]*-[^\s-]+$/.test(f[1])) continue;
        var p = splitNameArch(f[0]);
        if (!p || seen[f[0]]) continue;
        seen[f[0]] = true;
        var from = have[f[0]];
        if (obsoleting && !from) { out.push({ atom: _atom(p), to: f[1], kind: "new" }); continue; }
        out.push(from ? { atom: _atom(p), from: from, to: f[1], kind: "update" } : { atom: _atom(p), to: f[1], kind: "update" });
    }
    return out;
}
