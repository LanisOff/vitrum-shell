.pragma library
// Keyboard layout per app: every window of an app gets the layout last used in it.

// The layout index to switch to when `appId` takes focus, or -1 to leave it.
function switchTo(map, appId, layouts, current) {
    if (!appId || !map || !map[appId]) return -1;
    var i = layouts.indexOf(map[appId]);
    return i >= 0 && i !== current ? i : -1;
}

function remember(map, appId, layout) {
    var out = {}, k;
    for (k in map) out[k] = map[k];
    if (appId && layout) out[appId] = layout;
    return out;
}

// ------------------------------------------------------------ layouts -----
// Settings → Keyboard: keyboard.layouts, a list of xkb layouts in niri's order
// ("us", "de(nodeadkeys)": layout, and its variant in brackets). Empty: the
// layouts are niri's config.kdl's own. vitrum-theme writes the list into
// generated/input.kdl (niri_input.py), keeping config.kdl's xkb options.

// xkb keeps four groups at most.
var MAX_LAYOUTS = 4;

// "de(nodeadkeys)" → { layout: "de", variant: "nodeadkeys" }, or null.
function splitLayout(s) {
    var m = /^([a-z][a-z0-9_-]*)(?:\(([A-Za-z0-9_-]+)\))?$/.exec(String(s === undefined || s === null ? "" : s).trim());
    return m ? { layout: m[1], variant: m[2] || "" } : null;
}

function joinLayout(layout, variant) { return variant ? layout + "(" + variant + ")" : layout; }

// The first xkb { } block of a niri config, comments left out: its layout,
// variant and options as written ("" when not set), or null without one.
function parseXkb(text) {
    var src = String(text || "").replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/[^\n]*/g, "");
    var m = /(^|[\s{])xkb\s*\{([^}]*)\}/.exec(src);
    if (!m) return null;
    var body = m[2];
    function val(k) { var r = new RegExp("(^|\\s)" + k + "\\s+\"([^\"]*)\"").exec(body); return r ? r[2] : ""; }
    return { layout: val("layout"), variant: val("variant"), options: val("options") };
}

// The layouts an xkb block names, as list entries.
function xkbLayouts(xkb) {
    if (!xkb || !xkb.layout) return [];
    var ls = xkb.layout.split(","), vs = (xkb.variant || "").split(","), out = [], i;
    for (i = 0; i < ls.length; i++) {
        var l = ls[i].trim();
        if (l) out.push(joinLayout(l, (vs[i] || "").trim()));
    }
    return out;
}

// The valid, distinct entries of a saved list (at most four).
function cleanLayouts(list) {
    var out = [], i;
    if (!Array.isArray(list)) return out;
    for (i = 0; i < list.length && out.length < MAX_LAYOUTS; i++) {
        var e = splitLayout(list[i]);
        if (!e) continue;
        var s = joinLayout(e.layout, e.variant);
        if (out.indexOf(s) < 0) out.push(s);
    }
    return out;
}

// What the pane lists: the saved list, or config.kdl's layouts when there is none.
function currentLayouts(saved, configText) {
    var s = cleanLayouts(saved);
    return s.length ? s : xkbLayouts(parseXkb(configText));
}

// xkb's catalogue (rules/evdev.lst): every layout and variant with its name,
// as { id: "de(nodeadkeys)", name: "German (no dead keys)" }, layouts first.
function parseRules(text) {
    var out = [], section = "", lines = String(text || "").split("\n"), i;
    for (i = 0; i < lines.length; i++) {
        var line = lines[i];
        var h = /^!\s*(\w+)/.exec(line);
        if (h) { section = h[1]; continue; }
        var m;
        if (section === "layout" && (m = /^\s+(\S+)\s+(.+?)\s*$/.exec(line)))
            out.push({ id: m[1], name: m[2] });
        else if (section === "variant" && (m = /^\s+(\S+)\s+(\S+):\s+(.+?)\s*$/.exec(line)))
            out.push({ id: joinLayout(m[2], m[1]), name: m[3] });
    }
    return out;
}

// A layout's name from the catalogue, else its id.
function layoutName(rules, id) {
    for (var i = 0; i < (rules || []).length; i++) if (rules[i].id === id) return rules[i].name;
    return id;
}

// Catalogue entries matching a query (by name or id), not already in `taken`.
function searchLayouts(rules, query, taken, limit) {
    var q = String(query || "").trim().toLowerCase(), out = [], i;
    var t = taken || [], n = limit || 8;
    if (!q) return out;
    var starts = [], has = [];
    for (i = 0; i < (rules || []).length; i++) {
        var r = rules[i];
        if (t.indexOf(r.id) >= 0) continue;
        var name = r.name.toLowerCase(), id = r.id.toLowerCase();
        if (id === q || name.indexOf(q) === 0) starts.push(r);
        else if (name.indexOf(q) >= 0 || id.indexOf(q) === 0) has.push(r);
    }
    out = starts.concat(has);
    return out.slice(0, n);
}

// The list with `id` added at the end; unchanged when it is there already, invalid or the list is full.
function addLayout(list, id) {
    var l = cleanLayouts(list), e = splitLayout(id);
    if (!e) return l;
    var s = joinLayout(e.layout, e.variant);
    if (l.indexOf(s) >= 0 || l.length >= MAX_LAYOUTS) return l;
    return l.concat([s]);
}

// Without the i-th layout; the last one stays (niri needs a layout).
function removeLayout(list, i) {
    var l = cleanLayouts(list);
    if (l.length <= 1 || i < 0 || i >= l.length) return l;
    l.splice(i, 1);
    return l;
}

// The i-th layout moved by d places (-1 up, +1 down).
function moveLayout(list, i, d) {
    var l = cleanLayouts(list), j = i + d;
    if (i < 0 || i >= l.length || j < 0 || j >= l.length) return l;
    var x = l[i]; l[i] = l[j]; l[j] = x;
    return l;
}

// The short label (bar, lock, polkit) for niri's layout name: "English (US)" → US,
// "German" → DE, "Ukrainian" → UA; else the first two letters.
var SHORT = { English: "EN", Russian: "RU", German: "DE", French: "FR", Spanish: "ES", Ukrainian: "UA",
    Belarusian: "BY", Kazakh: "KZ", Polish: "PL", Czech: "CZ", Slovak: "SK", Slovenian: "SI", Italian: "IT",
    Portuguese: "PT", Japanese: "JP", Korean: "KR", Chinese: "CN", Greek: "GR", Hebrew: "IL", Arabic: "AR",
    Turkish: "TR", Swedish: "SE", Norwegian: "NO", Danish: "DK", Finnish: "FI", Dutch: "NL", Hungarian: "HU",
    Romanian: "RO", Bulgarian: "BG", Serbian: "RS", Croatian: "HR", Georgian: "GE", Armenian: "AM",
    Estonian: "EE", Latvian: "LV", Lithuanian: "LT", Vietnamese: "VN", Thai: "TH", Persian: "IR",
    Icelandic: "IS", Irish: "IE", Macedonian: "MK", Albanian: "AL", Azerbaijani: "AZ", Uzbek: "UZ",
    Mongolian: "MN", Kyrgyz: "KG", Tajik: "TJ", Tatar: "TT", Bosnian: "BA", Hindi: "HI", Bangla: "BD" };
function shortName(name) {
    var l = String(name || "");
    if (!l) return "";
    var m = /\(([A-Z]{2})\)/.exec(l);
    if (m) return m[1];
    var base = l.split(" (")[0].trim();
    return (SHORT[base] || l.slice(0, 2)).toUpperCase();
}

// Ids for niri's layout names ("English (US)" → "us"), for when there is no
// config to read them from; names the catalogue does not know are left out.
function layoutsFromNames(rules, names) {
    var out = [], i, j;
    for (i = 0; i < (names || []).length; i++)
        for (j = 0; j < (rules || []).length; j++)
            if (rules[j].name === names[i]) { if (out.indexOf(rules[j].id) < 0) out.push(rules[j].id); break; }
    return out;
}
