.pragma library
// The keybind sheet: binds.json (written from KEYBINDS.md by the installer)
// grouped by section, searched by title, section or the keys themselves, or
// narrowed to the modifiers held down.

var NAMES = {
    Mod: "Super", Super: "Super", Ctrl: "Ctrl", Control: "Ctrl", Alt: "Alt", Shift: "Shift", ISO_Level3_Shift: "AltGr",
    Slash: "/", Backslash: "\\", Period: ".", Comma: ",", Semicolon: ";", Apostrophe: "'", Grave: "`",
    Minus: "−", Equal: "=", Plus: "+", BracketLeft: "[", BracketRight: "]",
    Left: "←", Right: "→", Up: "↑", Down: "↓", Page_Up: "PgUp", Page_Down: "PgDn",
    Return: "Enter", Escape: "Esc", BackSpace: "Backspace", Delete: "Del", space: "Space", Space: "Space",
    WheelScrollDown: "Wheel ↓", WheelScrollUp: "Wheel ↑", WheelScrollLeft: "Wheel ←", WheelScrollRight: "Wheel →",
    MouseLeft: "Click", MouseRight: "Right click", MouseMiddle: "Middle click",
    XF86AudioRaiseVolume: "Volume +", XF86AudioLowerVolume: "Volume −", XF86AudioMute: "Mute",
    XF86AudioMicMute: "Mic mute", XF86AudioPlay: "Play", XF86AudioPause: "Pause", XF86AudioNext: "Next",
    XF86AudioPrev: "Previous", XF86AudioStop: "Stop",
    XF86MonBrightnessUp: "Brightness +", XF86MonBrightnessDown: "Brightness −", Print: "Print"
};

// "Mod+Shift+Slash" → caps; a space separates chords of a sequence (tmux's
// prefix, then a key): "Ctrl+a |" → Ctrl A › |.
function keyCaps(keys) {
    var chords = String(keys || "").split(" ").filter(function (c) { return c.length > 0; });
    var out = [];
    for (var i = 0; i < chords.length; i++) {
        if (i > 0) out.push("›");
        out = out.concat(_chordCaps(chords[i]));
    }
    return out;
}

function _chordCaps(chord) {
    var out = [];
    // "+" alone (or a trailing "++") is the plus key itself.
    var parts = chord === "+" ? ["Plus"] : chord.replace(/\+\+$/, "+Plus").split("+");
    for (var i = 0; i < parts.length; i++) {
        var p = parts[i];
        if (!p) continue;
        if (NAMES[p] !== undefined) out.push(NAMES[p]);
        else if (p.length === 1) out.push(p.toUpperCase());
        else out.push(p);
    }
    return out;
}

function _words(s) { return String(s || "").toLowerCase().split(/\s+/).filter(function (w) { return w.length > 0; }); }

// Every word of the query must appear in the title, the section or the caps.
function _matches(b, words) {
    if (words.length === 0) return true;
    var hay = (String(b.title || "") + " " + String(b.section || "") + " " + keyCaps(b.keys).join(" ") + " " + String(b.keys || "")).toLowerCase();
    var caps = keyCaps(b.keys).map(function (c) { return c.toLowerCase(); });
    for (var i = 0; i < words.length; i++) {
        var w = words[i];
        // A single character is a key: it has to be a whole cap, not any letter in a title.
        if (w.length === 1 ? caps.indexOf(w) < 0 : hay.indexOf(w) < 0) return false;
    }
    return true;
}

// KEYBINDS.md's words where they are niri's and not plain ones.
var PLAIN = {
    "Window switcher (next)": "Window switcher",
    "Window switcher (previous)": "Window switcher, backwards",
    "Cycle the material": "Switch material",
    "Capture": "Capture screen",
    "Screenshot (niri native)": "Screenshot picker",
    "Maximize column (keeps gaps)": "Maximize column",
    "Switch focus between floating and tiling layers": "Focus floating or tiled windows",
    "Cycle preset column widths (⅓ → ½ → ⅔)": "Cycle column width",
    "Cycle preset window heights": "Cycle window height",
    "Consume/expel window left (stack or unstack)": "Stack or unstack window left",
    "Consume/expel window right (stack or unstack)": "Stack or unstack window right",
    "Focus workspace 1–9": "Go to workspace",
    "Move column to workspace 1–9": "Move column to workspace",
    "Finder": "Files",
    "Quit niri": "Log out"
};
// "… (keyboard)", "… (mouse)": another way to the same action, so the same row.
function plainTitle(title) {
    var t = String(title || "").replace(/ \((keyboard|mouse)\)$/, "");
    return PLAIN[t] || t;
}

// Actions that differ in their last key only: one row, the keys side by side.
// find: what shows all of them in Settings.
var FAMILIES = [
    { title: "Move focus", find: "Focus", members: ["Focus column left", "Focus column right", "Focus window up", "Focus window down"] },
    { title: "Move", find: "Move", members: ["Move column left", "Move column right", "Move window up", "Move window down"] },
    { title: "Focus monitor", find: "Focus monitor", members: ["Focus monitor left", "Focus monitor right", "Focus monitor up", "Focus monitor down"] },
    { title: "Move column to monitor", find: "column to monitor", members: ["Move column to monitor left", "Move column to monitor right", "Move column to monitor up", "Move column to monitor down"] },
    { title: "Resize column", find: "column width", members: ["Shrink column width 10%", "Grow column width 10%"] },
    { title: "Resize window", find: "window height", members: ["Shrink window height 10%", "Grow window height 10%"] },
    { title: "Stack or unstack window", find: "Stack or", members: ["Stack or unstack window left", "Stack or unstack window right"] },
    { title: "Scroll workspaces", find: "Focus workspace", members: ["Focus workspace down", "Focus workspace up"] },
    { title: "Send column up or down", find: "column to workspace", members: ["Move column to workspace down", "Move column to workspace up"] }
];

function _mergeFamily(rows, fam) {
    var members = [];
    for (var i = 0; i < fam.members.length; i++) {
        var found = rows.filter(function (r) { return r.title === fam.members[i]; })[0];
        if (!found) return rows;
        members.push(found);
    }
    var alts = [];
    for (var a = 0; a < members[0].alts.length; a++) {
        var head = members[0].alts[a].slice(0, -1), keys = [];
        for (var m = 0; m < members.length; m++) {
            var alt = members[m].alts[a];
            // A key changed in Settings no longer fits the row: the rows stay apart.
            if (members[m].alts.length !== members[0].alts.length || !alt || alt.slice(0, -1).join(" ") !== head.join(" ")) return rows;
            keys.push(alt[alt.length - 1]);
        }
        alts.push(head.concat([keys.join(" ").replace("Wheel ↓ Wheel ↑", "Wheel")]));
    }
    var row = { title: fam.title, alts: alts, find: fam.find, hit: members.some(function (r) { return r.hit; }) };
    var out = [];
    rows.forEach(function (r) {
        if (r === members[0]) out.push(row);
        else if (members.indexOf(r) < 0) out.push(r);
    });
    return out;
}

// Super 1, Super 2 … Super 9 → Super 1…9.
function _digitRange(alts) {
    var out = [], at = {};
    alts.forEach(function (alt) {
        var last = alt[alt.length - 1], head = alt.slice(0, -1).join(" ");
        if (!/^[0-9]$/.test(last)) { out.push(alt); return; }
        if (at[head] === undefined) { at[head] = out.length; out.push(alt.slice()); return; }
        var kept = out[at[head]];
        kept[kept.length - 1] = kept[kept.length - 1].charAt(0) + "…" + last;
    });
    return out;
}

// The modifiers of a bind (of its first chord, for tmux's sequences), as held does.
function _mods(keys) {
    var parts = String(keys || "").split(" ")[0].split("+").slice(0, -1), m = {};
    for (var i = 0; i < parts.length; i++) {
        if (parts[i] === "Mod" || parts[i] === "Super") m.super = true;
        else if (parts[i] === "Ctrl" || parts[i] === "Control") m.ctrl = true;
        else if (parts[i] === "Alt") m.alt = true;
        else if (parts[i] === "Shift") m.shift = true;
    }
    return m;
}
var _MOD_ORDER = [["super", "Super"], ["ctrl", "Ctrl"], ["alt", "Alt"], ["shift", "Shift"]];
function _heldFits(keys, held) {
    if (!heldLabel(held)) return true;
    var m = _mods(keys);
    return _MOD_ORDER.every(function (o) { return !!m[o[0]] === !!held[o[0]]; });
}

// Qt's keys for the modifiers.
var _HELD_KEY = { 0x01000020: "shift", 0x01000021: "ctrl", 0x01000022: "super", 0x01000023: "alt", 0x01000053: "super", 0x01000054: "super" };
// held after a key went down or up; the same object when it is not a modifier.
function heldKeys(held, qtKey, down) {
    var name = _HELD_KEY[qtKey];
    if (!name) return held;
    var out = {};
    for (var k in held) out[k] = held[k];
    if (down) out[name] = true; else delete out[name];
    return out;
}
// "Super + Shift", "" when nothing is held.
function heldLabel(held) {
    return _MOD_ORDER.filter(function (o) { return held && held[o[0]]; })
                     .map(function (o) { return o[1]; }).join(" + ");
}

// → [{ section, rows: [{ title, alts: [caps…], find }] }], sections and rows in
// file order. Binds with the same title in a section are one row with every
// key set (arrows and HJKL); a row matches if any of them does. held (optional):
// only binds with exactly these modifiers. find: what finds the row in Settings.
function group(binds, query, held) {
    var words = _words(query);
    var order = [], by = {};
    var all = binds || [];
    for (var i = 0; i < all.length; i++) {
        var b = all[i];
        if (!b) continue;
        if (b.hidden) continue;
        var s = b.section || "Other";
        var title = plainTitle(b.title || b.action || "");
        if (!by[s]) { by[s] = { section: s, rows: [], index: {} }; order.push(s); }
        var sec = by[s];
        var row = sec.index[title];
        if (!row) { row = sec.index[title] = { title: title, alts: [], hit: false, find: title }; sec.rows.push(row); }
        row.alts.push(keyCaps(b.keys));
        if (_matches(b, words) && _heldFits(b.keys, held)) row.hit = true;
    }
    var out = [];
    for (var j = 0; j < order.length; j++) {
        var merged = by[order[j]].rows;
        for (var f = 0; f < FAMILIES.length; f++) merged = _mergeFamily(merged, FAMILIES[f]);
        var rows = merged.filter(function (r) { return r.hit; })
                         .map(function (r) { return { title: r.title, alts: _digitRange(r.alts), find: r.find }; });
        if (rows.length) out.push({ section: order[j], rows: rows });
    }
    return out;
}

// What most people reach for, first when the sheet opens.
var ESSENTIALS = ["Launcher", "Overview", "Window switcher", "Move focus", "Go to workspace", "Close window",
                  "Toggle fullscreen", "Terminal", "Browser", "Files", "Settings", "Control Centre",
                  "Notification Centre", "Clipboard history", "Region screenshot", "Lock screen"];

// The sheet: group()'s sections, under the essentials (wide: true) while nothing narrows them.
function sheet(binds, query, held) {
    var sections = group(binds, query, held);
    if (_words(query).length || heldLabel(held)) return sections;
    var rows = [];
    ESSENTIALS.forEach(function (title) {
        for (var i = 0; i < sections.length; i++) {
            var r = sections[i].rows.filter(function (x) { return x.title === title; })[0];
            if (r) { rows.push(r); return; }
        }
    });
    return rows.length ? [{ section: "Essentials", rows: rows, wide: true }].concat(sections) : sections;
}

// Sections into n columns, in order, each to the shortest so far: no holes
// under a short section beside a long one.
function columns(sections, n) {
    var cols = [], heights = [];
    for (var i = 0; i < Math.max(1, n); i++) { cols.push([]); heights.push(0); }
    (sections || []).forEach(function (s) {
        var at = 0;
        for (var c = 1; c < cols.length; c++) if (heights[c] < heights[at]) at = c;
        cols[at].push(s);
        heights[at] += s.rows.length + 2;      // the title and the gap count as rows
    });
    return cols;
}

// ---------------------------------------------------- the user's own binds ---
// overrides.kdl, read live by the sheet: KEYBINDS.md reaches binds.json only
// through the installer, but binds added here work the moment niri reloads.

function _humanize(action) {
    var a = String(action || "").replace(/-/g, " ").trim();
    return a ? a.charAt(0).toUpperCase() + a.slice(1) : "";
}

// Lines of a binds { } block: `Keys [props] { action args; }`.
function parseKdlBinds(text) {
    var out = [];
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].replace(/\/\/.*$/, "").trim();
        var m = line.match(/^([A-Za-z0-9_+]+)\s*(.*?)\{\s*(.*?)\s*;?\s*\}\s*$/);
        if (!m || m[1] === "binds") continue;
        var props = m[2], body = m[3];
        if (/hotkey-overlay-title\s*=\s*null/.test(props)) continue;
        var t = props.match(/hotkey-overlay-title\s*=\s*"([^"]*)"/);
        var title;
        if (t) title = t[1];
        else {
            var words = body.match(/"[^"]*"|[^\s"]+/g) || [];
            var verb = words.shift() || "";
            var args = words.map(function (w) { return w.replace(/^"|"$/g, ""); });
            title = verb === "spawn" || verb === "spawn-sh" ? args.join(" ") : _humanize(verb) + (args.length ? " " + args.join(" ") : "");
        }
        out.push({ keys: m[1], title: title });
    }
    return out;
}

// The user's binds over the keymap's: a known key keeps its section with the
// user's title; a new one goes to "Your binds".
function mergeBinds(base, own) {
    var out = (base || []).filter(function (b) { return b && !b.hidden; });
    var at = {};
    for (var i = 0; i < out.length; i++) at[String(out[i].keys).toLowerCase()] = i;
    for (var j = 0; j < (own || []).length; j++) {
        var o = own[j], key = String(o.keys).toLowerCase();
        if (at[key] !== undefined) {
            var b = out[at[key]];
            out[at[key]] = { section: b.section, keys: b.keys, title: o.title };
        } else {
            at[key] = out.length;
            out.push({ section: "Your binds", keys: o.keys, title: o.title });
        }
    }
    return out;
}

// ------------------------------------------------- Settings: your changes ---
// keybinds.changes { "<default keys>": "<new keys>" | null } and keybinds.own
// [{ keys, command, title }] over the catalogue (binds.json), as niri gets
// them from vitrum-theme. Used by the Settings pane and by the sheet.

function effective(catalogue, changes, own) {
    var ch = changes || {}, out = [];
    var cat = catalogue || [];
    for (var i = 0; i < cat.length; i++) {
        var b = cat[i];
        if (!b || b.hidden) continue;
        var has = Object.prototype.hasOwnProperty.call(ch, b.keys);
        var off = has && !ch[b.keys];
        out.push({ section: b.section, title: plainTitle(b.title || b.action), default: b.keys,
                   keys: off ? "" : (has ? String(ch[b.keys]) : b.keys), changed: has && !off, off: off });
    }
    var o = own || [];
    for (var j = 0; j < o.length; j++) {
        if (!o[j] || !o[j].keys) continue;
        out.push({ section: "Your binds", title: o[j].title || o[j].command, keys: o[j].keys,
                   command: o[j].command, own: j, default: "", changed: false, off: false });
    }
    return out;
}

function conflict(list, keys, selfDefault, selfOwn) {
    var want = String(keys || "").toLowerCase();
    if (!want) return null;
    for (var i = 0; i < (list || []).length; i++) {
        var e = list[i];
        if (e.off || String(e.keys).toLowerCase() !== want) continue;
        if (e.own !== undefined ? e.own === selfOwn : (selfDefault && e.default === selfDefault)) continue;
        return e;
    }
    return null;
}

// xkb keycodes (evdev + 8) of the main block, so a bind records the same key
// whatever layout is active (Russian letters included).
var SCAN = {
    10: "1", 11: "2", 12: "3", 13: "4", 14: "5", 15: "6", 16: "7", 17: "8", 18: "9", 19: "0", 20: "Minus", 21: "Equal",
    24: "Q", 25: "W", 26: "E", 27: "R", 28: "T", 29: "Y", 30: "U", 31: "I", 32: "O", 33: "P", 34: "BracketLeft", 35: "BracketRight",
    38: "A", 39: "S", 40: "D", 41: "F", 42: "G", 43: "H", 44: "J", 45: "K", 46: "L", 47: "Semicolon", 48: "Apostrophe", 49: "Grave",
    51: "Backslash", 52: "Z", 53: "X", 54: "C", 55: "V", 56: "B", 57: "N", 58: "M", 59: "Comma", 60: "Period", 61: "Slash"
};
var PUNCT = { "/": "Slash", "\\": "Backslash", ".": "Period", ",": "Comma", ";": "Semicolon", "'": "Apostrophe",
              "`": "Grave", "-": "Minus", "=": "Equal", "[": "BracketLeft", "]": "BracketRight" };
var SPECIAL = {
    0x01000000: "Escape", 0x01000001: "Tab", 0x01000003: "BackSpace", 0x01000004: "Return", 0x01000005: "Return",
    0x01000006: "Insert", 0x01000007: "Delete", 0x01000009: "Print", 0x01000010: "Home", 0x01000011: "End",
    0x01000012: "Left", 0x01000013: "Up", 0x01000014: "Right", 0x01000015: "Down",
    0x01000016: "Page_Up", 0x01000017: "Page_Down", 0x20: "Space"
};
var MODIFIER_KEYS = { 0x01000020: 1, 0x01000021: 1, 0x01000022: 1, 0x01000023: 1, 0x01001103: 1, 0x01000053: 1, 0x01000054: 1 };

function keyName(qtKey, text, scanCode) {
    if (MODIFIER_KEYS[qtKey]) return "";
    if (SCAN[scanCode]) return SCAN[scanCode];
    if (SPECIAL[qtKey]) return SPECIAL[qtKey];
    if (qtKey >= 0x01000030 && qtKey <= 0x01000052) return "F" + (qtKey - 0x01000030 + 1);
    if (qtKey >= 0x41 && qtKey <= 0x5a) return String.fromCharCode(qtKey);
    if (qtKey >= 0x30 && qtKey <= 0x39) return String.fromCharCode(qtKey);
    var t = String(text || "");
    if (PUNCT[t]) return PUNCT[t];
    return "";
}

function combo(mods, key) {
    var m = mods || {}, parts = [];
    if (m.super) parts.push("Mod");
    if (m.ctrl) parts.push("Ctrl");
    if (m.alt) parts.push("Alt");
    if (m.shift) parts.push("Shift");
    parts.push(key);
    return parts.join("+");
}
