.pragma library
// Settings → Displays: niri's outputs JSON in, output blocks (displays.kdl) out.

function _q(s) { return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"'; }
function _float(v) { var s = String(Number(v)); return s.indexOf(".") >= 0 ? s : s + ".0"; }

// list: [{ name, mode?: "WxH@R", scale?: number, off?: bool, vrr?: "off"|"on"|"on-demand" }]
function outputsKdl(list) {
    var out = "// Written by vitrum Settings → Displays.\n";
    for (var i = 0; i < list.length; i++) {
        var o = list[i];
        out += "output " + _q(o.name) + " {\n";
        if (o.off) out += "    off\n";
        else {
            if (o.mode) out += "    mode " + _q(o.mode) + "\n";
            if (o.scale) out += "    scale " + _float(o.scale) + "\n";
            if (o.vrr === "on") out += "    variable-refresh-rate\n";
            else if (o.vrr === "on-demand") out += "    variable-refresh-rate on-demand=true\n";
        }
        out += "}\n";
    }
    return out;
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
