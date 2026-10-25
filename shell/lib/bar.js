.pragma library
// Bar layout from settings, and the column minimap for niri's scrolling layout.

var MODULES = ["workspaces", "minimap", "context", "cpu", "memory", "temperature", "gpu",
               "tray", "keyboard", "network", "bluetooth", "volume", "microphone",
               "dnd", "notifications", "recording", "power", "privacy", "awake", "sharing", "timer", "vpn", "emerge", "updates", "vitrum", "shutdown", "phone", "game"];
// left / center / right, and activities: islands right of the centre that are
// only there while their activity runs.
var SIDES = ["left", "center", "activities", "right"];

function parseLayout(layout) {
    var out = { left: [], center: [], activities: [], right: [] }, warnings = [], seen = {};
    SIDES.forEach(function (side) {
        var islands = (layout && layout[side]) || [];
        if (!Array.isArray(islands)) {
            warnings.push("bar." + side + ": not a list of islands");
            return;
        }
        islands.forEach(function (island) {
            // A bare module name is an island of one; anything else that is not a list is dropped.
            if (typeof island === "string") island = [island];
            if (!Array.isArray(island)) {
                if (island !== null && island !== undefined) warnings.push("bar." + side + ": not an island " + JSON.stringify(island));
                else warnings.push("bar." + side + ": empty island");
                return;
            }
            var kept = island.filter(function (m) {
                var known = typeof m === "string" && MODULES.indexOf(m) >= 0;
                if (!known) warnings.push("bar." + side + ": unknown module " + JSON.stringify(m));
                // A module shows once: two trays, two clocks fight over the same thing.
                else if (seen[m]) { warnings.push("bar." + side + ": " + m + " is already in the bar"); known = false; }
                if (known) seen[m] = true;
                return known;
            });
            if (kept.length) out[side].push(kept);
        });
    });
    return { layout: out, warnings: warnings };
}

// Columns of workspace wsId, at most maxCols, keeping the focused one in view.
function minimapColumns(windows, wsId, maxCols) {
    var cols = {}, base = 0;
    windows.forEach(function (w) {
        if (w.workspaceId !== wsId || !w.layout || !w.layout.pos_in_scrolling_layout) return;
        var c = w.layout.pos_in_scrolling_layout[0];
        var width = w.layout.tile_size ? w.layout.tile_size[0] : 0;
        if (!cols[c]) cols[c] = { col: c, width: 0, appId: w.appId, focused: false, visible: false };
        cols[c].width = Math.max(cols[c].width, width);
        if (w.focused) { cols[c].focused = true; cols[c].appId = w.appId; }
        if (w.layout.tile_pos_in_workspace_view) cols[c].visible = true;
    });
    var list = Object.keys(cols).map(function (k) { return cols[k]; }).sort(function (a, b) { return a.col - b.col; });
    list.forEach(function (c) { if (!base || c.width < base) base = c.width; });
    list.forEach(function (c) { c.widthFrac = base ? Math.round(c.width / base * 10) / 10 : 1; delete c.width; });
    var start = 0;
    if (list.length > maxCols) {
        var f = 0;
        for (var i = 0; i < list.length; i++) if (list[i].focused) f = i;
        start = Math.max(0, Math.min(f - Math.floor(maxCols / 2), list.length - maxCols));
    }
    var shown = list.slice(start, start + maxCols);
    return { columns: shown, moreLeft: start, moreRight: list.length - start - shown.length };
}

function modules() { return MODULES.slice(); }

// The primary screen (the tray, the idle inhibitor, toasts): the configured
// one while it is connected, else the top-left screen of the layout — the list
// order is the connectors', which says nothing about where you look.
// screens: [{ name, x, y }] → a name, or "".
function primaryScreen(screens, configured) {
    var list = screens || [];
    for (var i = 0; i < list.length; i++) if (configured && list[i].name === configured) return configured;
    var best = null;
    for (var j = 0; j < list.length; j++) {
        var s = list[j];
        if (!best || s.x < best.x || (s.x === best.x && s.y < best.y)) best = s;
    }
    return best ? best.name : "";
}

// ------------------------------------------------------------ the editor ---
// The contract with the bar editor (apps/settings/panes/BarPane.qml). Every
// function here is pure: it never changes what it is given.
//
// Positions are read against the layout as it is shown when the drop happens
// (before the move):
//   { side, island, index }  a slot in that island: index 0 is before its first
//                            module, island.length after its last
//   { side, gap }            a new island at that gap: 0 before the side's first
//                            island, islands.length after its last
// Indices out of range clamp; a side that is not one of SIDES changes nothing.

function _choice(key, def) {
    return { key: key, label: "Show", type: "choice", values: ["both", "icon", "value"], names: ["Icon and value", "Icon", "Value"], def: def };
}

// What the editor shows for each module: a short name for chips, an icons.json
// icon, one line about it, and its options (full settings keys; `needs`: the
// boolean key an option only works with, off greys the option out).
var CATALOG = {
    workspaces:    { name: "Workspaces", icon: "workspaces", description: "This screen's workspaces; click one to go there, scroll to switch.",
                     options: [{ key: "bar.minimap", label: "Column minimap beside them", type: "toggle", def: false }] },
    minimap:       { name: "Column minimap", icon: "distribute-h", description: "The columns of this screen's workspace; click one to focus it." },
    context:       { name: "Title & clock", icon: "clock", description: "The date and time; the playing track, or the window's title on hover.",
                     options: [{ key: "bar.modules.context.title", label: "Window title on hover", type: "toggle", def: true },
                               { key: "clock.seconds", label: "Seconds", type: "toggle", def: false },
                               { key: "clock.h24", label: "24-hour clock", type: "toggle", def: true },
                               { key: "media.lyricsInBar", label: "Lyrics in the bar", type: "toggle", def: false, needs: "media.lyrics" }] },
    cpu:           { name: "CPU", icon: "cpu", description: "Processor load; click for resources.", options: [_choice("bar.modules.cpu.show", "both")] },
    memory:        { name: "Memory", icon: "memory", description: "Memory in use; click for resources.", options: [_choice("bar.modules.memory.show", "both")] },
    temperature:   { name: "Temperature", icon: "temperature", description: "The processor's temperature, where a sensor reports it.", options: [_choice("bar.modules.temperature.show", "both")] },
    gpu:           { name: "GPU", icon: "gpu", description: "Graphics load, where the card reports it.", options: [_choice("bar.modules.gpu.show", "both")] },
    tray:          { name: "Tray", icon: "apps", description: "Apps' tray icons, on the primary screen." },
    keyboard:      { name: "Keyboard", icon: "keyboard", description: "The keyboard layout while there are several; click for the next.",
                     options: [{ key: "bar.modules.keyboard.long", label: "Full layout name", type: "toggle", def: false }] },
    network:       { name: "Network", icon: "wifi", description: "Wired or Wi-Fi and its strength; click for the Control Centre." },
    bluetooth:     { name: "Bluetooth", icon: "bluetooth", description: "Bluetooth, and how many devices are connected." },
    volume:        { name: "Volume", icon: "volume-high", description: "Output volume; scroll to change it, middle-click to mute.",
                     options: [{ key: "bar.modules.volume.percent", label: "Show percent", type: "toggle", def: false }] },
    microphone:    { name: "Microphone", icon: "mic", description: "The microphone, muted or live; middle-click to mute." },
    dnd:           { name: "Do not disturb", icon: "dnd", description: "Shows while notifications are silenced." },
    notifications: { name: "Notifications", icon: "notifications", description: "Unread notifications; click for the notification centre." },
    recording:     { name: "Recording", icon: "recording", description: "Shows while the screen is recorded; click to stop." },
    power:         { name: "Power", icon: "power", description: "Opens the power menu: lock, sleep, restart, shut down." },
    privacy:       { name: "Privacy", icon: "shield", description: "Dots while the microphone, camera or screen is in use." },
    awake:         { name: "Stay awake", icon: "coffee", description: "Shows while the computer is kept awake, with the minutes left." },
    sharing:       { name: "Screen sharing", icon: "screen-share", description: "Shows while the screen is shared, and with which app." },
    timer:         { name: "Timers", icon: "timer", description: "The nearest timer or pomodoro counting down." },
    vpn:           { name: "VPN", icon: "vpn", description: "Shows while a VPN carries the traffic." },
    emerge:        { name: "Package build", icon: "build", description: "Shows while emerge builds or pacman, xbps or dnf installs, and how far." },
    updates:       { name: "Updates", icon: "update", description: "Package updates waiting; click for the list." },
    vitrum:        { name: "vitrum update", icon: "vitrum-update", description: "Shows when a new vitrum is out; click for what is new." },
    shutdown:      { name: "Shutdown timer", icon: "power", description: "Shows while a shutdown is scheduled; click to cancel it." },
    phone:         { name: "Phone", icon: "phone", description: "Your phone (KDE Connect) while it is in reach, with its battery." },
    game:          { name: "Game mode", icon: "gamepad", description: "Shows while game mode is on, with the game's name." }
};

function _copy(v) { return JSON.parse(JSON.stringify(v)); }

function _entry(id) {
    var c = CATALOG[id];
    return { id: id, name: c.name, icon: c.icon, description: c.description, options: _copy(c.options || []) };
}

// [{ id, name, icon, description, options: [{ key, label, type, values?, names?, def }] }], in MODULES order.
function catalog() { return MODULES.map(_entry); }

// One catalog entry, or null.
function info(id) { return typeof id === "string" && MODULES.indexOf(id) >= 0 ? _entry(id) : null; }

// The raw layout one screen's bar uses: its own when bar.screens[screen].own,
// else the shared bar.layout. bar is the whole `bar` settings object.
function layoutFor(bar, screen) {
    var shared = bar && typeof bar === "object" && bar.layout && typeof bar.layout === "object" ? bar.layout : {};
    if (!screen || !bar || !bar.screens || typeof bar.screens !== "object") return shared;
    var s = bar.screens[screen];
    if (s && typeof s === "object" && s.own === true && s.layout && typeof s.layout === "object" && !Array.isArray(s.layout)) return s.layout;
    return shared;
}

// { left, center, activities, right }: islands of known module ids, as parseLayout.
function normalize(layout) { return parseLayout(layout).layout; }

// The layout settings.defaults.json ships (bar.layout); a test keeps them equal.
var DEFAULT_LAYOUT = {
    left: [["workspaces"]],
    center: [["context"]],
    activities: [["recording"], ["sharing"], ["timer"], ["game"], ["emerge"], ["shutdown"], ["vitrum"]],
    right: [["privacy"], ["cpu", "memory", "temperature", "gpu"],
            ["tray", "keyboard", "network", "vpn", "bluetooth", "phone", "volume", "microphone", "awake", "dnd", "notifications", "updates"]]
};
function defaultLayout() { return _copy(DEFAULT_LAYOUT); }

// Every module id in the layout, left to right (left, center, activities, right).
function usedModules(layout) {
    var l = normalize(layout), out = [];
    SIDES.forEach(function (side) { l[side].forEach(function (island) { out = out.concat(island); }); });
    return out;
}

// Where id is: { side, island, index }, or null.
function _find(l, id) {
    for (var s = 0; s < SIDES.length; s++)
        for (var i = 0; i < l[SIDES[s]].length; i++) {
            var k = l[SIDES[s]][i].indexOf(id);
            if (k >= 0) return { side: SIDES[s], island: i, index: k };
        }
    return null;
}

function _int(v, lo, hi, fallback) {
    var n = typeof v === "number" ? v : typeof v === "string" && v.trim() !== "" ? Number(v) : NaN;
    if (!isFinite(n)) n = fallback;
    n = Math.floor(n);
    return Math.max(lo, Math.min(hi, n));
}

// The module at `at`, or null when `at` does not point at one.
function _at(l, at) {
    if (!at || SIDES.indexOf(at.side) < 0) return null;
    var islands = l[at.side], i = Number(at.island), k = Number(at.index);
    if (!(i >= 0 && i < islands.length && Math.floor(i) === i)) return null;
    if (!(k >= 0 && k < islands[i].length && Math.floor(k) === k)) return null;
    return { side: at.side, island: i, index: k, id: islands[i][k] };
}

// Puts id at `to` in l (changed in place; l is a copy). The slot the module
// leaves is a null until _strip, so `to` reads against the layout as shown.
function _put(l, id, to) {
    var islands = l[to.side], n = islands.length;
    var gapForm = to.gap !== undefined && to.gap !== null;
    if (gapForm || n === 0) {
        islands.splice(_int(to.gap, 0, n, n), 0, [id]);
        return;
    }
    var island = islands[_int(to.island, 0, n - 1, n - 1)];
    island.splice(_int(to.index, 0, island.length, island.length), 0, id);
}

function _strip(l) {
    var out = {};
    SIDES.forEach(function (side) {
        out[side] = l[side].map(function (island) { return island.filter(function (m) { return m !== null; }); })
                           .filter(function (island) { return island.length > 0; });
    });
    return out;
}

function _validTo(to) { return !!to && SIDES.indexOf(to.side) >= 0; }

// The module at `from` moved to `to`; an island it leaves empty goes.
function moveModule(layout, from, to) {
    var l = _copy(normalize(layout)), src = _at(l, from);
    if (!src || !_validTo(to)) return _strip(l);
    l[src.side][src.island][src.index] = null;
    _put(l, src.id, to);
    return _strip(l);
}

// id put at `to`; one already in the layout is moved there, not doubled.
function insertModule(layout, id, to) {
    var l = normalize(layout);
    if (typeof id !== "string" || MODULES.indexOf(id) < 0 || !_validTo(to)) return _copy(l);
    var here = _find(l, id);
    if (here) return moveModule(l, here, to);
    l = _copy(l);
    _put(l, id, to);
    return _strip(l);
}

// The module at `at` gone; an island it leaves empty goes too.
function removeModule(layout, at) {
    var l = _copy(normalize(layout)), src = _at(l, at);
    if (src) l[src.side][src.island][src.index] = null;
    return _strip(l);
}

// ------------------------------------------------------------- the bar ---
// The column minimap is a module of its own, and also an option of the
// workspaces (bar.minimap): with it on, a layout that has no minimap gets one
// right after the workspaces.
function withMinimap(layout, on) {
    var l = _copy(normalize(layout));
    if (!on || _find(l, "minimap")) return l;
    var w = _find(l, "workspaces");
    if (w) l[w.side][w.island].splice(w.index + 1, 0, "minimap");
    return l;
}

// What turns the list oldKeys into newKeys (unique strings) without touching
// what stays: ops for a ListModel, applied in order —
//   { op: "remove", index }  { op: "move", from, to }  { op: "insert", index, key }
// (move as ListModel.move(from, to, 1): the item ends up at `to`).
function planList(oldKeys, newKeys) {
    var cur = (oldKeys || []).slice(), want = newKeys || [], ops = [];
    for (var i = cur.length - 1; i >= 0; i--)
        if (want.indexOf(cur[i]) < 0) { ops.push({ op: "remove", index: i }); cur.splice(i, 1); }
    for (var j = 0; j < want.length; j++) {
        var at = cur.indexOf(want[j]);
        if (at < 0) { ops.push({ op: "insert", index: j, key: want[j] }); cur.splice(j, 0, want[j]); }
        else if (at !== j) { ops.push({ op: "move", from: at, to: j }); cur.splice(at, 1); cur.splice(j, 0, want[j]); }
    }
    return ops;
}

// The islands of one side, kept across a layout change: each new island
// continues the old one it shares the most modules with (so its modules, and
// a panel open from it, live on), the rest are new.
//   old: [[id]], oldUids: [int] (parallel), now: [[id]], next: the next free uid
//   → { uids (parallel to now), next, ops } — ops as planList's, with uid and
//     mods (the island's ids joined by ",") on insert, plus { op: "set", index, mods }.
function planIslands(old, oldUids, now, next) {
    old = old || []; oldUids = oldUids || []; now = now || [];
    var taken = {}, uids = [], n = next || 0;
    now.forEach(function (island) {
        var best = -1, score = 0;
        for (var i = 0; i < old.length; i++) {
            if (taken[i]) continue;
            var s = island.filter(function (m) { return old[i].indexOf(m) >= 0; }).length;
            if (s > score) { score = s; best = i; }
        }
        if (best >= 0) { taken[best] = true; uids.push(oldUids[best]); }
        else uids.push(n++);
    });
    var ops = planList(oldUids.map(String), uids.map(String)).map(function (o) {
        if (o.op !== "insert") return o;
        return { op: "insert", index: o.index, uid: Number(o.key), mods: now[o.index].join(",") };
    });
    var before = {};
    oldUids.forEach(function (u, i) { before[u] = old[i].join(","); });
    now.forEach(function (island, i) {
        var mods = island.join(",");
        if (before[uids[i]] !== undefined && before[uids[i]] !== mods) ops.push({ op: "set", index: i, mods: mods });
    });
    return { uids: uids, next: n, ops: ops };
}
