.pragma library
// Capture: selection geometry, file names and recorder command lines.
// Rectangles are { x, y, w, h } in an output's logical coordinates.

function _clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

// A drag from (x0, y0) to (x1, y1), in any direction, clamped to the screen.
function normRect(x0, y0, x1, y1, bounds) {
    var ax = Math.round(_clamp(Math.min(x0, x1), 0, bounds.w)), ay = Math.round(_clamp(Math.min(y0, y1), 0, bounds.h));
    var bx = Math.round(_clamp(Math.max(x0, x1), 0, bounds.w)), by = Math.round(_clamp(Math.max(y0, y1), 0, bounds.h));
    return { x: ax, y: ay, w: bx - ax, h: by - ay };
}

// Drag a handle ("tl", "t", "tr", "r", "br", "b", "bl", "l") or the whole
// selection ("move") by (dx, dy). The opposite edge stays put; a side never
// crosses the other one (1 px minimum).
function resize(r, handle, dx, dy, bounds) {
    if (handle === "move")
        return { x: _clamp(r.x + dx, 0, bounds.w - r.w), y: _clamp(r.y + dy, 0, bounds.h - r.h), w: r.w, h: r.h };
    var l = r.x, t = r.y, rr = r.x + r.w, b = r.y + r.h;
    if (handle.indexOf("l") >= 0) l = _clamp(l + dx, 0, rr - 1);
    if (handle.indexOf("r") >= 0) rr = _clamp(rr + dx, l + 1, bounds.w);
    if (handle.indexOf("t") >= 0) t = _clamp(t + dy, 0, b - 1);
    if (handle.indexOf("b") >= 0) b = _clamp(b + dy, t + 1, bounds.h);
    return { x: l, y: t, w: rr - l, h: b - t };
}

// "x,y wxh" in global logical coordinates (grim, wf-recorder, slurp's format).
function geometry(r, origin) {
    return (r.x + origin.x) + "," + (r.y + origin.y) + " " + r.w + "x" + r.h;
}

// gpu-screen-recorder's -region: "WxH+X+Y".
function gsrRegion(r, origin) {
    return r.w + "x" + r.h + "+" + (r.x + origin.x) + "+" + (r.y + origin.y);
}

function _pad(n) { return (n < 10 ? "0" : "") + n; }

function fileName(kind, d) {
    var stamp = d.getFullYear() + "-" + _pad(d.getMonth() + 1) + "-" + _pad(d.getDate()) + " "
              + _pad(d.getHours()) + "-" + _pad(d.getMinutes()) + "-" + _pad(d.getSeconds());
    return kind === "video" ? "Recording " + stamp + ".mp4" : "Screenshot " + stamp + ".png";
}

// The two switches → what is recorded: "" | "system" | "mic" | "both".
function audioMode(system, mic) { return system && mic ? "both" : system ? "system" : mic ? "mic" : ""; }

// The sink both are mixed into for wf-recorder (one device only); the capture
// service creates it for the recording and removes it after.
var MIX_SINK = "vitrum_rec";
function needsMix(tool, audio) { return tool === "wf-recorder" && audio === "both"; }

// o: { output, origin, rect (null → the whole output), file, audio (audioMode), fps }
function recorderCommand(tool, o) {
    if (tool === "wf-recorder") {
        var w = ["wf-recorder", "-y"];
        w = w.concat(o.rect ? ["-g", geometry(o.rect, o.origin)] : ["-o", o.output]);
        w = w.concat(["-r", String(o.fps)]);
        // Pulse names: the output's monitor is what you hear, the source is the mic.
        var dev = { system: "@DEFAULT_MONITOR@", mic: "@DEFAULT_SOURCE@", both: MIX_SINK + ".monitor" }[o.audio];
        if (dev) w.push("--audio=" + dev);
        return w.concat(["-f", o.file]);
    }
    var g = ["gpu-screen-recorder"];
    g = g.concat(o.rect ? ["-w", "region", "-region", gsrRegion(o.rect, o.origin)] : ["-w", o.output]);
    g = g.concat(["-f", String(o.fps)]);
    var a = { system: "default_output", mic: "default_input", both: "default_output|default_input" }[o.audio];
    if (a) g = g.concat(["-a", a]);
    return g.concat(["-o", o.file]);
}

// setting: "auto" | a recorder name; installed: name → bool. Auto is
// wf-recorder: it records through the compositor's screencopy, which niri has
// on every GPU; gpu-screen-recorder's KMS capture hung on niri + NVIDIA.
function pickRecorder(setting, installed) {
    if (setting && setting !== "auto") return setting;
    if (installed["wf-recorder"]) return "wf-recorder";
    if (installed["gpu-screen-recorder"]) return "gpu-screen-recorder";
    return "";
}

// The recorder to try when this one does not get going.
function otherRecorder(current, installed) {
    var other = current === "wf-recorder" ? "gpu-screen-recorder" : "wf-recorder";
    return installed[other] ? other : "";
}

// A press that barely moved selects a window or a screen, not an area.
function isClick(r) { return r.w < 6 && r.h < 6; }

function sizeLabel(r, scale) {
    return Math.round(r.w * scale) + " × " + Math.round(r.h * scale);
}
