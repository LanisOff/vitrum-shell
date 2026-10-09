.pragma library
// Desktop widgets: placement, the stored list, and the calendar's month grid.
// An item is { id, type, output, x, y, w, h, options } in output-logical pixels.

var SIZES = {
    clock:     { w: 320, h: 160 },
    calendar:  { w: 288, h: 272 },
    weather:   { w: 288, h: 160 },
    system:    { w: 288, h: 184 },
    media:     { w: 384, h: 232 },
    notes:     { w: 288, h: 240 },
    shortcuts: { w: 288, h: 112 },
    battery:   { w: 200, h: 120 },
    monitor:   { w: 360, h: 300 }
};
var INTERACTIVE = { notes: true, media: true, shortcuts: true };
// No plate: the widget is its own glass (the clock's digits).
var BARE = { clock: true };

function types() { return Object.keys(SIZES); }
function defaultSize(type) { return SIZES[type] || { w: 240, h: 160 }; }
function interactive(type) { return !!INTERACTIVE[type]; }
function bare(type) { return !!BARE[type]; }

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
function add(items, type, output, screen, step, top, mkId) {
    var s = defaultSize(type), margin = 32, mine = forOutput(items, output);
    var pos = { x: margin, y: top + margin };
    var stepXY = Math.max(step, 8);
    search:
    for (var y = top + margin; y + s.h <= screen.h - margin; y += stepXY) {
        for (var x = margin; x + s.w <= screen.w - margin; x += stepXY) {
            var r = { x: x, y: y, w: s.w, h: s.h }, free = true;
            for (var i = 0; i < mine.length; i++) if (_overlaps(r, mine[i], step)) { free = false; break; }
            if (free) { pos = { x: x, y: y }; break search; }
        }
    }
    return items.concat([{ id: mkId(), type: type, output: output, x: pos.x, y: pos.y, w: s.w, h: s.h, options: {} }]);
}

function _num(v, fallback) { return typeof v === "number" && isFinite(v) ? v : fallback; }

// What comes from settings: known types only, numbers where numbers belong, ids.
function sanitize(items, mkId) {
    var out = [];
    for (var i = 0; i < (items || []).length; i++) {
        var it = items[i];
        if (!it || !SIZES[it.type] || typeof it.output !== "string") continue;
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
