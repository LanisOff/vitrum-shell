.pragma library
// Bar layout from settings, and the column minimap for niri's scrolling layout.

var MODULES = ["workspaces", "minimap", "context", "cpu", "memory", "temperature", "gpu",
               "tray", "keyboard", "network", "bluetooth", "volume", "microphone",
               "dnd", "notifications", "recording", "power", "privacy", "awake", "sharing", "timer", "vpn", "emerge", "updates", "vitrum", "shutdown", "phone"];
// left / center / right, and activities: islands right of the centre that are
// only there while their activity runs.
var SIDES = ["left", "center", "activities", "right"];

function parseLayout(layout) {
    var out = { left: [], center: [], activities: [], right: [] }, warnings = [];
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
