.pragma library
// Desktop widgets: placement, the stored list, and the calendar's month grid.
// An item is { id, type, output, x, y, w, h, options } in output-logical pixels.

// The catalog: what each widget is, the sizes it comes in, and its options.
//   category  time | productivity | system | media | apps (the gallery's chips)
//   sizes     the presets it lays itself out for (S M L XL); def the one it starts at
//   interactive  takes clicks outside the editor (the rest let them through)
//   bare      no plate: the content is its own glass (the glass clock)
//   options   the schema the editor's form is built from:
//             { key, label, type: bool|choice|text|number|list|color|folder,
//               default, choices: [{ value, label }], min, max, step, hint,
//               hidden: kept in options but not in the form (a note's text) }
function _c(v, l) { return { value: v, label: l }; }
var HOURS = [_c("24", "24-hour"), _c("12", "12-hour")];
var COLORS = [_c("accent", "Accent"), _c("0", "Red"), _c("60", "Yellow"), _c("120", "Green"),
              _c("180", "Cyan"), _c("240", "Blue"), _c("300", "Magenta")];

var CATALOG = {
    // ---- time and weather
    clock: { name: "Clock", icon: "clock", category: "time", sizes: ["S", "M", "L"], def: "M", bare: true, options: [
        { key: "style", label: "Style", type: "choice", default: "glass", choices: [_c("glass", "Glass digits"), _c("digital", "On a plate")] },
        { key: "hours", label: "Hours", type: "choice", default: "24", choices: HOURS },
        { key: "seconds", label: "Seconds", type: "bool", default: false },
        { key: "date", label: "Date", type: "bool", default: true }] },
    analog: { name: "Analog clock", icon: "clock", category: "time", sizes: ["S", "L"], def: "S", options: [
        { key: "seconds", label: "Second hand", type: "bool", default: true },
        { key: "numbers", label: "Numbers", type: "bool", default: false },
        { key: "color", label: "Hand colour", type: "color", default: "accent", choices: COLORS }] },
    worldclock: { name: "World clocks", icon: "world", category: "time", sizes: ["S", "M", "L"], def: "M", options: [
        { key: "zones", label: "Time zones", type: "list", default: ["Europe/London", "America/New_York", "Asia/Tokyo"], hint: "IANA names, e.g. Europe/Berlin" },
        { key: "hours", label: "Hours", type: "choice", default: "24", choices: HOURS }] },
    calendar: { name: "Calendar", icon: "calendar", category: "time", sizes: ["S", "L"], def: "L", options: [
        { key: "firstDay", label: "Week starts on", type: "choice", default: "1", choices: [_c("1", "Monday"), _c("0", "Sunday")] },
        { key: "weekNumbers", label: "Week numbers", type: "bool", default: false }] },
    weather: { name: "Weather", icon: "weather-partly", category: "time", sizes: ["S", "M", "L"], def: "M", options: [
        { key: "hours", label: "Hours ahead", type: "number", default: 5, min: 0, max: 8, step: 1 },
        { key: "details", label: "Feels like, wind, humidity", type: "bool", default: true }] },
    sun: { name: "Sun", icon: "sun", category: "time", sizes: ["S", "M"], def: "M", options: [
        { key: "daylight", label: "Length of the day", type: "bool", default: true }] },
    // ---- productivity
    notes: { name: "Notes", icon: "edit", category: "productivity", sizes: ["S", "M", "L"], def: "M", interactive: true, options: [
        { key: "fontSize", label: "Text size", type: "number", default: 14, min: 11, max: 28, step: 1 },
        { key: "text", label: "Text", type: "text", default: "", hidden: true }] },
    todo: { name: "To-do", icon: "todo", category: "productivity", sizes: ["S", "M", "L"], def: "M", interactive: true, options: [
        { key: "title", label: "Title", type: "text", default: "To-do" },
        { key: "hideDone", label: "Hide done", type: "bool", default: false },
        { key: "items", label: "Items", type: "list", default: [], hidden: true }] },
    timer: { name: "Timer", icon: "timer", category: "productivity", sizes: ["S", "M"], def: "S", interactive: true, options: [
        { key: "presets", label: "Quick timers (minutes)", type: "list", default: ["5", "10", "25"] },
        { key: "pomodoro", label: "Pomodoro button", type: "bool", default: true }] },
    countdown: { name: "Countdown", icon: "countdown", category: "productivity", sizes: ["S", "M"], def: "S", options: [
        { key: "title", label: "Title", type: "text", default: "New Year" },
        { key: "date", label: "Date", type: "text", default: "2027-01-01", hint: "YYYY-MM-DD, or YYYY-MM-DD HH:MM" },
        { key: "color", label: "Colour", type: "color", default: "accent", choices: COLORS }] },
    // ---- system
    system: { name: "System", icon: "cpu", category: "system", sizes: ["S", "M", "L"], def: "M", options: [
        { key: "cpu", label: "Processor", type: "bool", default: true },
        { key: "memory", label: "Memory", type: "bool", default: true },
        { key: "temperature", label: "Temperature", type: "bool", default: true },
        { key: "style", label: "Meters", type: "choice", default: "rings", choices: [_c("rings", "Rings"), _c("bars", "Bars")] }] },
    monitor: { name: "Monitor", icon: "graph", category: "system", sizes: ["M", "L", "XL"], def: "L", options: [
        { key: "cpu", label: "Processor graph", type: "bool", default: true },
        { key: "memory", label: "Memory graph", type: "bool", default: true },
        { key: "network", label: "Network graph", type: "bool", default: true }] },
    gpu: { name: "GPU", icon: "gpu", category: "system", sizes: ["S", "M", "L"], def: "M", options: [
        { key: "graph", label: "Load graph", type: "bool", default: true }] },
    disks: { name: "Disks", icon: "disk", category: "system", sizes: ["S", "M", "L"], def: "M", options: [
        { key: "mounts", label: "Mount points", type: "list", default: [], hint: "Empty: every real disk" }] },
    netspeed: { name: "Network speed", icon: "speed", category: "system", sizes: ["S", "M"], def: "M", options: [
        { key: "iface", label: "Interface", type: "text", default: "", hint: "Empty: the busiest one" },
        { key: "graph", label: "Graph", type: "bool", default: true }] },
    battery: { name: "Battery", icon: "battery", category: "system", sizes: ["S", "M"], def: "S", options: [
        { key: "time", label: "Time left", type: "bool", default: true }] },
    devices: { name: "Device batteries", icon: "devices", category: "system", sizes: ["S", "M", "L"], def: "M", options: [
        { key: "bluetooth", label: "Bluetooth devices", type: "bool", default: true },
        { key: "phone", label: "Phone (KDE Connect)", type: "bool", default: true }] },
    updates: { name: "Updates", icon: "update", category: "system", sizes: ["S", "M"], def: "S", interactive: true, options: [
        { key: "list", label: "List the packages", type: "bool", default: true }] },
    toggles: { name: "Quick toggles", icon: "toggles", category: "system", sizes: ["S", "M"], def: "M", interactive: true, options: [
        { key: "wifi", label: "Wi-Fi", type: "bool", default: true },
        { key: "bluetooth", label: "Bluetooth", type: "bool", default: true },
        { key: "dnd", label: "Do not disturb", type: "bool", default: true },
        { key: "awake", label: "Stay awake", type: "bool", default: true }] },
    // ---- media and decor
    media: { name: "Now playing", icon: "music", category: "media", sizes: ["M", "L", "XL"], def: "L", interactive: true, options: [
        { key: "lyrics", label: "Lyrics", type: "bool", default: true },
        { key: "visualizer", label: "Visualizer", type: "bool", default: true }] },
    visualizer: { name: "Visualizer", icon: "mixer", category: "media", sizes: ["S", "M", "L", "XL"], def: "M", options: [
        { key: "mirror", label: "Mirrored", type: "bool", default: false },
        { key: "color", label: "Colour", type: "color", default: "accent", choices: COLORS }] },
    photo: { name: "Photo frame", icon: "photo", category: "media", sizes: ["S", "M", "L", "XL"], def: "L", options: [
        { key: "folder", label: "Folder", type: "folder", default: "~/Pictures" },
        { key: "interval", label: "Next photo every (seconds)", type: "number", default: 30, min: 5, max: 600, step: 5 },
        { key: "shuffle", label: "Shuffle", type: "bool", default: true }] },
    quote: { name: "Quote", icon: "quote", category: "media", sizes: ["M", "L"], def: "M", interactive: true, options: [
        { key: "every", label: "New quote", type: "choice", default: "day", choices: [_c("day", "Every day"), _c("hour", "Every hour"), _c("click", "On click")] }] },
    // ---- games and apps
    shortcuts: { name: "Shortcuts", icon: "apps", category: "apps", sizes: ["S", "M"], def: "M", interactive: true, options: [
        { key: "apps", label: "Apps", type: "list", default: [], hint: "Desktop file names, e.g. firefox; empty: the dock's" }] },
    appfolder: { name: "App folder", icon: "folder-apps", category: "apps", sizes: ["S", "L"], def: "S", interactive: true, options: [
        { key: "title", label: "Title", type: "text", default: "Apps" },
        { key: "apps", label: "Apps", type: "list", default: [], hint: "Desktop file names; empty: the most used" }] },
    steam: { name: "Steam games", icon: "gamepad", category: "apps", sizes: ["M", "L", "XL"], def: "M", interactive: true, options: [
        { key: "count", label: "Games", type: "number", default: 4, min: 2, max: 8, step: 1 }] }
};
var MISSING = { name: "Missing widget", icon: "help", category: "custom", sizes: ["S", "M"], def: "S", options: [], missing: true };

var CELL = 72, GAP = 16;
function presetSize(p) {
    var cells = { S: [2, 2], M: [4, 2], L: [4, 4], XL: [6, 4] }[p] || [4, 2];
    return { w: cells[0] * CELL + (cells[0] - 1) * GAP, h: cells[1] * CELL + (cells[1] - 1) * GAP };
}
// Any free size, read as the nearest preset: what the widget lays itself out for.
function sizeClass(w, h) {
    if (w < 248 && h < 248) return "S";
    if (h < 248) return "M";
    if (w < 424) return "L";
    return "XL";
}

// A custom widget's entry (script:<id>, qml:<dir>) from `custom` ({ type: entry }), with the gaps filled.
function meta(type, custom) {
    if (CATALOG[type]) return CATALOG[type];
    var c = custom && custom[type];
    if (!c) return MISSING;
    var sizes = (c.sizes || []).filter(function (s) { return ["S", "M", "L", "XL"].indexOf(s) >= 0; });
    if (!sizes.length) sizes = ["S", "M", "L"];
    return { name: String(c.name || type), icon: String(c.icon || "code"), category: "custom", sizes: sizes,
             def: sizes.indexOf(c.def) >= 0 ? c.def : sizes[0], interactive: !!c.interactive, options: c.options || [], custom: true };
}
function types() { return Object.keys(CATALOG); }
function defaultSize(type, custom) { return presetSize(meta(type, custom).def); }
function interactive(type, custom) { return !!meta(type, custom).interactive; }
// The glass clock has no plate; on a plate it is an ordinary widget.
function bare(type, options) { return type === "clock" && (!options || options.style !== "digital"); }

// Options as the widget gets them: every key of the schema, of its type; a
// value of the wrong type (an older version's, a hand edit) is the default.
function withDefaults(type, options, custom) {
    var o = options && typeof options === "object" ? options : {}, out = {}, k;
    for (k in o) out[k] = o[k];
    var schema = meta(type, custom).options || [];
    for (var i = 0; i < schema.length; i++) {
        var s = schema[i], v = o[s.key], d = s.default;
        var good;
        switch (s.type) {
        case "bool": good = typeof v === "boolean"; break;
        case "number":
            good = typeof v === "number" && isFinite(v);
            if (good) v = Math.max(s.min !== undefined ? s.min : -Infinity, Math.min(s.max !== undefined ? s.max : Infinity, v));
            break;
        case "choice": case "color":
            // A choices that is no list (a hand-written manifest): any text is taken.
            good = typeof v === "string" && (!Array.isArray(s.choices) || s.choices.some(function (c) { return c && c.value === v; })); break;
        case "list":
            good = Array.isArray(v);
            if (good) v = v.filter(function (x) { return typeof x === "string"; });
            break;
        default: good = typeof v === "string";
        }
        out[s.key] = good ? v : (Array.isArray(d) ? d.slice() : d);
    }
    return out;
}

function snap(v, step) { return step > 0 ? Math.round(v / step) * step : v; }

function _clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

// Keep a rectangle on screen, at least `min`, on the grid.
function place(r, screen, step, min) {
    var w = _clamp(Math.max(snap(r.w, step), min.w), 0, screen.w);
    var h = _clamp(Math.max(snap(r.h, step), min.h), 0, screen.h);
    return { x: _clamp(snap(r.x, step), 0, screen.w - w), y: _clamp(snap(r.y, step), 0, screen.h - h), w: w, h: h };
}

// Line a dragged or resized rectangle up with its neighbours: an edge within
// `threshold` of another widget's edge takes it, or sits `gap` away from it
// (beside / under it), so a layout falls into straight columns and even gaps
// without the hand having to. kind "move" shifts x and y; "resize" moves only
// the right and bottom edges. → the rectangle, adjusted.
function align(r, others, kind, opts) {
    var t = opts.threshold, g = opts.gap;
    function nearest(value, targets) {
        var best = null, d = t + 1;
        for (var i = 0; i < targets.length; i++) {
            var dd = Math.abs(targets[i] - value);
            if (dd <= t && dd < d) { d = dd; best = targets[i]; }
        }
        return best;
    }
    var xs = [], ys = [];          // candidate positions for the edges being moved
    var out = { x: r.x, y: r.y, w: r.w, h: r.h };
    for (var i = 0; i < (others || []).length; i++) {
        var o = others[i];
        xs.push(o.x, o.x + o.w, o.x + o.w + g, o.x - g);
        ys.push(o.y, o.y + o.h, o.y + o.h + g, o.y - g);
    }
    if (kind === "move") {
        // Either the left or the right edge may be the one that lines up.
        var l = nearest(r.x, xs), rr = nearest(r.x + r.w, xs);
        if (l !== null && (rr === null || Math.abs(l - r.x) <= Math.abs(rr - r.x - r.w))) out.x = l;
        else if (rr !== null) out.x = rr - r.w;
        var tp = nearest(r.y, ys), bt = nearest(r.y + r.h, ys);
        if (tp !== null && (bt === null || Math.abs(tp - r.y) <= Math.abs(bt - r.y - r.h))) out.y = tp;
        else if (bt !== null) out.y = bt - r.h;
    } else {
        var re = nearest(r.x + r.w, xs), be = nearest(r.y + r.h, ys);
        if (re !== null && re > r.x) out.w = re - r.x;
        if (be !== null && be > r.y) out.h = be - r.y;
    }
    return out;
}

function forOutput(items, output) {
    return (items || []).filter(function (i) { return i.output === output; });
}

function update(items, id, patch) {
    return items.map(function (i) {
        if (i.id !== id) return i;
        var n = {};
        for (var k in i) n[k] = i[k];
        for (var p in patch) n[p] = patch[p];
        return n;
    });
}

function remove(items, id) { return items.filter(function (i) { return i.id !== id; }); }

function _overlaps(a, b, gap) {
    return a.x < b.x + b.w + gap && a.x + a.w + gap > b.x && a.y < b.y + b.h + gap && a.y + a.h + gap > b.y;
}

// A new widget of `type` at the first free spot, scanning rows from the top
// left; `top` is the space the bar takes. mkId() makes the id.
function add(items, type, output, screen, step, top, mkId, custom) {
    var s = defaultSize(type, custom);
    var pos = freeSpot(items, output, s, screen, step, top);
    return items.concat([{ id: mkId(), type: type, output: output, x: pos.x, y: pos.y, w: s.w, h: s.h, options: {} }]);
}

// The first spot a widget of `size` fits on `output`, scanning rows from the top left.
function freeSpot(items, output, size, screen, step, top) {
    var margin = 32, mine = forOutput(items, output), stepXY = Math.max(step, 8);
    for (var y = (top || 0) + margin; y + size.h <= screen.h - margin; y += stepXY) {
        for (var x = margin; x + size.w <= screen.w - margin; x += stepXY) {
            var r = { x: x, y: y, w: size.w, h: size.h }, free = true;
            for (var i = 0; i < mine.length; i++) if (_overlaps(r, mine[i], step)) { free = false; break; }
            if (free) return { x: x, y: y };
        }
    }
    return { x: margin, y: (top || 0) + margin };
}

function _num(v, fallback) { return typeof v === "number" && isFinite(v) ? v : fallback; }

// Any type at all: a built-in one, a custom one (script:<id>, qml:<folder>),
// or one this build does not know (an older or newer build's, a custom
// widget since deleted) — that one is a "Missing widget" plate (meta), which
// can be removed, rather than gone at the next save.
function knownType(t) { return typeof t === "string" && t.length > 0; }

// What comes from settings: any typed entry (knownType), numbers where numbers belong, ids.
function sanitize(items, mkId) {
    var out = [];
    for (var i = 0; i < (items || []).length; i++) {
        var it = items[i];
        if (!it || !knownType(it.type) || typeof it.output !== "string") continue;
        var s = defaultSize(it.type);
        out.push({ id: typeof it.id === "string" && it.id ? it.id : mkId(), type: it.type, output: it.output,
                   x: _num(it.x, 0), y: _num(it.y, 0), w: _num(it.w, s.w), h: _num(it.h, s.h),
                   options: it.options && typeof it.options === "object" ? it.options : {} });
    }
    return out;
}

// 42 days (6 weeks) around a month; firstDay 0 = Sunday, 1 = Monday.
function monthGrid(year, month, firstDay) {
    var first = new Date(year, month, 1);
    var lead = (first.getDay() - firstDay + 7) % 7;
    var out = [];
    for (var i = 0; i < 42; i++) {
        var d = new Date(year, month, 1 - lead + i);
        out.push({ day: d.getDate(), month: d.getMonth(), year: d.getFullYear(), inMonth: d.getMonth() === month });
    }
    return out;
}

// How to turn the model's id list into the new one: indices to remove (from
// the end, so they stay valid) and ids to append. Order of the rest is kept.
function syncPlan(current, next) {
    var keep = {}, i, remove = [], add = [];
    for (i = 0; i < next.length; i++) keep[next[i]] = true;
    for (i = current.length - 1; i >= 0; i--) if (!keep[current[i]]) remove.push(i);
    var have = {};
    for (i = 0; i < current.length; i++) have[current[i]] = true;
    for (i = 0; i < next.length; i++) if (!have[next[i]]) add.push(next[i]);
    return { remove: remove, add: add };
}

// ---------------------------------------------------------------- editor ---

// A preset's size at the widget's own corner, kept on screen.
function presetRect(item, preset, bounds, step) {
    var s = presetSize(preset);
    return place({ x: item.x, y: item.y, w: s.w, h: s.h }, bounds, step, { w: 120, h: 80 });
}

// Where the scaled desktop sits in the editor: right of the sheet when this
// screen has it, centred otherwise; smaller than `scale` if the room is short.
function stageRect(screen, panelW, scale, withPanel, margin) {
    var x0 = withPanel ? panelW + 2 * margin : margin;
    var availW = screen.w - x0 - margin, availH = screen.h - 2 * margin;
    var s = Math.min(scale, availW / screen.w, availH / screen.h);
    var w = screen.w * s, h = screen.h * s;
    var x = withPanel ? x0 + (availW - w) / 2 : (screen.w - w) / 2;
    return { x: x, y: (screen.h - h) / 2, w: w, h: h, scale: s };
}
function toStage(p, st) { return { x: st.x + p.x * st.scale, y: st.y + p.y * st.scale }; }
function fromStage(p, st) { return { x: (p.x - st.x) / st.scale, y: (p.y - st.y) / st.scale }; }

function _copy(o) { return JSON.parse(JSON.stringify(o)); }
function _find(items, id) { for (var i = 0; i < items.length; i++) if (items[i].id === id) return items[i]; return null; }

// A copy beside the original (right, else below), else wherever there is room.
function duplicate(items, id, mkId, bounds, step) {
    var o = _find(items, id);
    if (!o) return items;
    var mine = forOutput(items, o.output);
    function fits(r) {
        if (r.x < 0 || r.y < 0 || r.x + r.w > bounds.w || r.y + r.h > bounds.h) return false;
        for (var i = 0; i < mine.length; i++) if (_overlaps(r, mine[i], 0)) return false;
        return true;
    }
    var right = { x: o.x + o.w + GAP, y: o.y, w: o.w, h: o.h }, below = { x: o.x, y: o.y + o.h + GAP, w: o.w, h: o.h };
    var pos = fits(right) ? right : fits(below) ? below : freeSpot(items, o.output, { w: o.w, h: o.h }, bounds, step, 0);
    var c = _copy(o);
    c.id = mkId(); c.x = pos.x; c.y = pos.y;
    return items.concat([c]);
}

function _selBox(sel) {
    var b = { l: Infinity, t: Infinity, r: -Infinity, b: -Infinity };
    for (var i = 0; i < sel.length; i++) {
        b.l = Math.min(b.l, sel[i].x); b.t = Math.min(b.t, sel[i].y);
        b.r = Math.max(b.r, sel[i].x + sel[i].w); b.b = Math.max(b.b, sel[i].y + sel[i].h);
    }
    return b;
}
// Line the selected widgets up on one edge or centre of what they cover together.
function alignItems(items, ids, how) {
    var sel = items.filter(function (i) { return ids.indexOf(i.id) >= 0; });
    if (sel.length < 2) return items;
    var b = _selBox(sel);
    return items.map(function (i) {
        if (ids.indexOf(i.id) < 0) return i;
        var n = _copy(i);
        if (how === "left") n.x = b.l;
        else if (how === "right") n.x = b.r - i.w;
        else if (how === "hcenter") n.x = Math.round((b.l + b.r) / 2 - i.w / 2);
        else if (how === "top") n.y = b.t;
        else if (how === "bottom") n.y = b.b - i.h;
        else if (how === "vcenter") n.y = Math.round((b.t + b.b) / 2 - i.h / 2);
        return n;
    });
}
// Even gaps between the selected widgets, the outer two staying put.
function distribute(items, ids, axis) {
    var sel = items.filter(function (i) { return ids.indexOf(i.id) >= 0; });
    if (sel.length < 3) return items;
    var p = axis === "v" ? "y" : "x", d = axis === "v" ? "h" : "w";
    sel.sort(function (a, b) { return a[p] - b[p]; });
    var first = sel[0], last = sel[sel.length - 1], sum = 0;
    for (var i = 0; i < sel.length; i++) sum += sel[i][d];
    var gap = (last[p] + last[d] - first[p] - sum) / (sel.length - 1);
    var at = {}, cur = first[p];
    for (i = 0; i < sel.length; i++) { at[sel[i].id] = Math.round(cur); cur += sel[i][d] + gap; }
    return items.map(function (it) {
        if (at[it.id] === undefined) return it;
        var n = _copy(it); n[p] = at[it.id]; return n;
    });
}
// To another screen, at `pos` there, kept on it.
function moveToOutput(items, id, output, pos, bounds, step) {
    return items.map(function (it) {
        if (it.id !== id) return it;
        var n = _copy(it), r = place({ x: pos.x, y: pos.y, w: it.w, h: it.h }, bounds, step, { w: 120, h: 80 });
        n.output = output; n.x = r.x; n.y = r.y; n.w = r.w; n.h = r.h;
        return n;
    });
}

// Undo/redo over whole drafts. h = { undo: [], redo: [] }; each returns { h, value }.
function historyPush(h, snapshot, limit) {
    var undo = h.undo.concat([snapshot]);
    var max = limit || 100;
    if (undo.length > max) undo = undo.slice(undo.length - max);
    return { h: { undo: undo, redo: [] }, value: null };
}
function historyUndo(h, current) {
    if (!h.undo.length) return { h: h, value: null };
    return { h: { undo: h.undo.slice(0, -1), redo: h.redo.concat([current]) }, value: h.undo[h.undo.length - 1] };
}
function historyRedo(h, current) {
    if (!h.redo.length) return { h: h, value: null };
    return { h: { undo: h.undo.concat([current]), redo: h.redo.slice(0, -1) }, value: h.redo[h.redo.length - 1] };
}

// What a script widget's command printed: JSON ({ value, unit, title, subtitle,
// progress, items, icon, history }), else lines — the value, a subtitle, then
// items. Bounded, whatever comes: 200 characters a string, 50 items.
function _cut(v) { return v === undefined || v === null ? "" : String(v).slice(0, 200); }
function parseScriptOutput(text) {
    var t = String(text || "").trim();
    var out = { value: "", unit: "", title: "", subtitle: "", progress: null, items: [], icon: "", history: [] };
    if (t.charAt(0) === "{") {
        try {
            var j = JSON.parse(t);
            out.value = _cut(j.value); out.unit = _cut(j.unit); out.title = _cut(j.title);
            out.subtitle = _cut(j.subtitle); out.icon = _cut(j.icon);
            if (typeof j.progress === "number" && isFinite(j.progress)) out.progress = Math.max(0, Math.min(1, j.progress));
            if (Array.isArray(j.items)) out.items = j.items.slice(0, 50).map(function (x) {
                return x && typeof x === "object" ? { label: _cut(x.label), value: _cut(x.value) } : _cut(x);
            });
            if (Array.isArray(j.history)) out.history = j.history.filter(function (x) { return typeof x === "number" && isFinite(x); }).slice(-200);
            return out;
        } catch (e) { /* not JSON after all: read it as lines */ }
    }
    var lines = t ? t.split("\n") : [];
    out.value = _cut(lines[0]);
    out.subtitle = _cut(lines[1]);
    out.items = lines.slice(2).filter(function (l) { return l.trim().length > 0; }).slice(0, 50).map(_cut);
    return out;
}

// The output under a global (layout) point; outs = Niri.outputs ({ name: { x, y, width, height } }).
function outputAt(outs, gx, gy) {
    for (var n in outs) {
        var o = outs[n];
        if (gx >= o.x && gx < o.x + o.width && gy >= o.y && gy < o.y + o.height) return n;
    }
    return "";
}
// A widget dragged out of `from`'s window, let go at `p` (that window's
// coordinates): which screen it lands on, and where on that screen's desktop —
// through its stage, which has no sheet (the sheet is on the screen dragged
// from). null when it was let go inside its own window, or over nothing.
function dropTarget(outs, from, p, panelW, scale, margin) {
    var f = outs[from];
    if (!f || (p.x >= 0 && p.y >= 0 && p.x < f.width && p.y < f.height)) return null;
    var name = outputAt(outs, f.x + p.x, f.y + p.y);
    if (!name || name === from) return null;
    var t = outs[name];
    var st = stageRect({ w: t.width, h: t.height }, panelW, scale, false, margin);
    var d = fromStage({ x: f.x + p.x - t.x, y: f.y + p.y - t.y }, st);
    return { output: name, x: d.x, y: d.y };
}

// The file under modules/desktop/widgets/ that shows a type.
var FILES = {
    clock: "Clock", calendar: "Calendar", weather: "Weather", system: "System", media: "Media", notes: "Notes",
    shortcuts: "Shortcuts", battery: "Battery", monitor: "Monitor", analog: "Analog", worldclock: "WorldClock",
    sun: "Sun", todo: "Todo", timer: "Timer", countdown: "Countdown", gpu: "Gpu", disks: "Disks", netspeed: "NetSpeed",
    devices: "Devices", updates: "Updates", toggles: "Toggles", visualizer: "Visualizer", photo: "Photo",
    quote: "Quote", appfolder: "AppFolder", steam: "Steam"
};
function widgetFile(type) {
    var t = String(type || "");
    if (t.indexOf("script:") === 0) return "ScriptWidget.qml";
    if (t.indexOf("qml:") === 0) return "QmlWidget.qml";
    return FILES[t] ? FILES[t] + "Widget.qml" : "";
}
