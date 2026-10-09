.pragma library
// Wallpaper: which file, the awww and mpvpaper command lines, when a live
// wallpaper is hidden, and the parallax offset.

var VIDEO = [".mp4", ".mkv", ".webm", ".mov", ".avi", ".gif"];
var TRANSITIONS = { grow: true, fade: true, none: true };

function isVideo(path) {
    var p = (path || "").toLowerCase();
    for (var i = 0; i < VIDEO.length; i++) if (p.length > VIDEO[i].length && p.slice(-VIDEO[i].length) === VIDEO[i]) return true;
    return false;
}

function expand(p, home) { return (p || "").replace(/^~(?=\/|$)/, home); }

// settings.wallpaper → the file for one output.
function pathFor(s, output, home) {
    var per = (s && s.perOutput) || {};
    return expand(per[output] || (s && s.path) || "", home);
}

// pos: { x, y } from the top left of the output, or null for the centre.
function awwwArgs(path, output, transition, pos, duration) {
    var t = TRANSITIONS[transition] ? transition : "grow";
    var a = ["awww", "img", path, "-o", output, "-t", t];
    a = a.concat(["--transition-pos", pos ? Math.round(pos.x) + "," + Math.round(pos.y) : "center"]);
    if (pos) a.push("--invert-y");
    return a.concat(["--transition-duration", String(duration), "--transition-fps", "60"]);
}

function mpvArgs(path, output, socket) {
    return ["mpvpaper", "-o", "no-audio loop hwdec=auto input-ipc-server=" + socket, output, path];
}

function mpvPause(paused) { return JSON.stringify({ command: ["set_property", "pause", !!paused] }) + "\n"; }

// tiles: [{ col, w, h, floating }] on the output's active workspace. Covered
// when the columns together span the output and each reaches (nearly) the
// bottom of the working area (the bar takes `top`).
function covered(tiles, out, top) {
    var cols = {}, any = false;
    for (var i = 0; i < tiles.length; i++) {
        var t = tiles[i];
        if (t.floating) continue;
        var c = cols[t.col] || (cols[t.col] = { w: 0, h: 0 });
        c.w = Math.max(c.w, t.w);
        c.h += t.h;
        any = true;
    }
    if (!any) return false;
    var width = 0, minH = Infinity;
    for (var k in cols) { width += cols[k].w; minH = Math.min(minH, cols[k].h); }
    return width >= out.w * 0.95 && minH >= (out.h - top) * 0.9;
}

function parallaxOffset(index, count, extra) {
    return count > 1 ? -extra * index / (count - 1) : 0;
}

function step(files, current, dir) {
    if (!files.length) return "";
    var i = files.indexOf(current);
    if (i < 0) return files[0];
    return files[(i + dir + files.length) % files.length];
}

// The other half of a day/night pair ("forest-day.jpg" ↔ "forest-night.jpg"),
// for the scheme to switch to; null when there is no pair or it is already right.
function counterpart(path, isDay) {
    var m = /^(.*[-_])(day|night)(\.[A-Za-z0-9]+)$/i.exec(String(path || ""));
    if (!m) return null;
    var night = m[2].toLowerCase() === "night";
    if (night !== !!isDay) return null;
    var word = night ? "day" : "night";
    if (m[2][0] === m[2][0].toUpperCase()) word = word[0].toUpperCase() + word.slice(1);
    return m[1] + word + m[3];
}

// The day and the night picture of a name-day / name-night pair, or the one
// picture for both (the login screen picks by the time). → { day, night } or null
function halves(path) {
    var p = String(path || "");
    if (!p) return null;
    var m = /^(.*[-_])(day|night)(\.[A-Za-z0-9]+)$/i.exec(p);
    if (!m) return { day: p, night: p };
    var up = m[2][0] === m[2][0].toUpperCase();
    return { day: m[1] + (up ? "Day" : "day") + m[3], night: m[1] + (up ? "Night" : "night") + m[3] };
}
