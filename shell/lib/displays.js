.pragma library
// Settings → Displays: niri's outputs JSON in, output blocks (displays.kdl) out.

function _q(s) { return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"'; }
function _float(v) { var s = String(Number(v)); return s.indexOf(".") >= 0 ? s : s + ".0"; }

// list: [{ name, mode?: "WxH@R", scale?: number, off?: bool, vrr?: "off"|"on"|"on-demand",
//          transform?: "normal"|"90"|"180"|"270", position?: { x, y }, primary?: bool, mirror?: "<output>" }]
// A mirrored output shows wl-mirror fullscreen (the shell runs it, services/Mirror.qml);
// its window rule puts that window there.
function outputsKdl(list) {
    var out = "// Written by vitrum Settings → Displays.\n";
    for (var i = 0; i < list.length; i++) {
        var o = list[i];
        out += "output " + _q(o.name) + " {\n";
        if (o.off) out += "    off\n";
        else {
            if (o.mode) out += "    mode " + _q(o.mode) + "\n";
            if (o.scale) out += "    scale " + _float(o.scale) + "\n";
            if (o.transform && o.transform !== "normal") out += "    transform " + _q(o.transform) + "\n";
            if (o.position) out += "    position x=" + Math.round(o.position.x) + " y=" + Math.round(o.position.y) + "\n";
            if (o.vrr === "on") out += "    variable-refresh-rate\n";
            else if (o.vrr === "on-demand") out += "    variable-refresh-rate on-demand=true\n";
            if (o.primary) out += "    focus-at-startup\n";
        }
        out += "}\n";
    }
    for (var j = 0; j < list.length; j++) {
        var m = list[j];
        if (!m.mirror || m.off) continue;
        out += "window-rule {\n    match app-id=" + _q("^at\\.yrlf\\.wl_mirror$") + " title=" + _q("^" + _re(mirrorTitle(m.mirror, m.name)) + "$") + "\n"
             + "    open-on-output " + _q(m.name) + "\n    open-fullscreen true\n    open-focused false\n}\n";
    }
    return out;
}

function _re(s) { return String(s).replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); }

// wl-mirror's window title for one mirror (its --title), what the rule matches.
function mirrorTitle(source, target) { return "vitrum mirror " + source + " on " + target; }

// The mirrors to run: [{ source, target }] — both screens there, the target on.
function mirrors(edits, present) {
    var out = [];
    Object.keys(edits || {}).forEach(function (t) {
        var e = edits[t];
        if (e && e.mirror && !e.off && present.indexOf(t) >= 0 && present.indexOf(e.mirror) >= 0 && e.mirror !== t) out.push({ source: e.mirror, target: t });
    });
    return out;
}

// niri's outputs JSON names the transform "Normal", "90", "Flipped90"…; the config, "normal", "90", "flipped-90".
function transformOf(o) {
    var t = o && o.logical ? String(o.logical.transform) : "Normal";
    var m = /^Flipped(\d+)?$/.exec(t);
    if (m) return m[1] ? "flipped-" + m[1] : "flipped";
    return t === "Normal" ? "normal" : t;
}

// The size a screen takes in the layout: its mode over its scale, turned with it.
function logicalSize(o, e) {
    e = e || {};
    var mode = e.mode || (modes(o)[0] || ""), wh = mode.split("@")[0].split("x");
    var w = Number(wh[0]) || (o.logical ? o.logical.width : 1920), h = Number(wh[1]) || (o.logical ? o.logical.height : 1080);
    var s = e.scale || scaleOf(o) || 1;
    var t = e.transform || transformOf(o);
    if (/90|270/.test(t)) { var x = w; w = h; h = x; }
    return { w: Math.round(w / s), h: Math.round(h / s) };
}

function _overlap(a, b) { return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h; }

// Where a screen dropped at (x, y) goes: against the edge of another screen
// (the nearest place that touches one and overlaps none), lined up with its
// edges or centre when close. rects: [{ x, y, w, h }]; i: the one moved.
function snap(rects, i, x, y, near) {
    var me = rects[i], others = rects.filter(function (r, k) { return k !== i; });
    if (!others.length) return { x: 0, y: 0 };
    near = near || Math.max(me.w, me.h) / 8;
    function align(v, lo, len, olen) {
        var c = [lo, lo + olen - len, lo + (olen - len) / 2];
        for (var k = 0; k < c.length; k++) if (Math.abs(v - c[k]) < near) return c[k];
        return v;
    }
    var cands = [];
    others.forEach(function (o) {
        var yy = Math.max(o.y - me.h + 1, Math.min(o.y + o.h - 1, y)), xx = Math.max(o.x - me.w + 1, Math.min(o.x + o.w - 1, x));
        yy = align(yy, o.y, me.h, o.h); xx = align(xx, o.x, me.w, o.w);
        cands.push({ x: o.x + o.w, y: yy }, { x: o.x - me.w, y: yy }, { x: xx, y: o.y + o.h }, { x: xx, y: o.y - me.h });
    });
    var best = null, bd = Infinity;
    cands.forEach(function (c) {
        var r = { x: c.x, y: c.y, w: me.w, h: me.h };
        if (others.some(function (o) { return _overlap(r, o); })) return;
        var d = Math.hypot(c.x - x, c.y - y);
        if (d < bd) { bd = d; best = c; }
    });
    return best ? { x: Math.round(best.x), y: Math.round(best.y) } : { x: me.x, y: me.y };
}

// The layout moved so its top-left corner is at 0,0.
function normalize(rects) {
    if (!rects.length) return rects;
    var mx = Math.min.apply(null, rects.map(function (r) { return r.x; })), my = Math.min.apply(null, rects.map(function (r) { return r.y; }));
    return rects.map(function (r) { return { x: r.x - mx, y: r.y - my, w: r.w, h: r.h }; });
}

function _mode(m) { return m.width + "x" + m.height + "@" + (m.refresh_rate / 1000).toFixed(3); }

// The output's modes as niri writes them, the current one first.
function modes(o) {
    var all = (o.modes || []).map(_mode), cur = o.current_mode;
    if (cur === null || cur === undefined || !o.modes || !o.modes[cur]) return all;
    var c = _mode(o.modes[cur]);
    return [c].concat(all.filter(function (m) { return m !== c; }));
}

// Each size the output can do, once, largest first ("2560x1440").
function resolutions(o) {
    var seen = {}, out = [];
    (o.modes || []).slice().sort(function (a, b) { return b.width * b.height - a.width * a.height || b.width - a.width; })
        .forEach(function (m) { var k = m.width + "x" + m.height; if (!seen[k]) { seen[k] = true; out.push(k); } });
    return out;
}

// The sizes worth showing first: the native (largest) one's shape, at least
// 1280 wide, and the one in use whatever it is.
function usualResolutions(o, current) {
    var all = resolutions(o);
    if (!all.length) return all;
    var n = all[0].split("x"), ratio = n[0] / n[1];
    return all.filter(function (r) {
        var p = r.split("x");
        return r === current || (p[0] >= 1280 && Math.abs(p[0] / p[1] - ratio) < 0.02);
    });
}

// A size's refresh rates as whole Hz, highest first; for each, the exact mode
// closest to it (60.000 over 59.940) — [{ hz, mode }].
function rates(o, res) {
    var by = {};
    (o.modes || []).forEach(function (m) {
        if (m.width + "x" + m.height !== res) return;
        var r = m.refresh_rate / 1000, hz = Math.round(r), cur = by[hz];
        if (!cur || Math.abs(r - hz) < Math.abs(cur.r - hz)) by[hz] = { hz: hz, r: r, mode: _mode(m) };
    });
    return Object.keys(by).map(function (k) { return by[k]; })
        .sort(function (a, b) { return b.hz - a.hz; })
        .map(function (x) { return { hz: x.hz, mode: x.mode }; });
}

// The mode for a size, keeping the rate when it has it, else its highest.
function pick(o, res, hz) {
    var rs = rates(o, res);
    for (var i = 0; i < rs.length; i++) if (rs[i].hz === hz) return rs[i].mode;
    return rs.length ? rs[0].mode : "";
}

function scaleOf(o) { return o.logical ? o.logical.scale : 1; }

// Can the output do variable refresh rate (niri's outputs JSON)?
function vrrSupported(o) { return !!(o && o.vrr_supported); }
