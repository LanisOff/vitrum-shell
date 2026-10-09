.pragma library
// The keybind sheet: binds.json (written from KEYBINDS.md by the installer)
// grouped by section, searched by title, section or the keys themselves.

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

// → [{ section, rows: [{ title, alts: [caps…] }] }], sections and rows in
// file order. Binds with the same title in a section are one row with every
// key set (arrows and HJKL); a row matches if any of them does.
function group(binds, query) {
    var words = _words(query);
    var order = [], by = {};
    var all = binds || [];
    for (var i = 0; i < all.length; i++) {
        var b = all[i];
        if (!b) continue;
        var s = b.section || "Other";
        var title = b.title || b.action || "";
        if (!by[s]) { by[s] = { section: s, rows: [], index: {} }; order.push(s); }
        var sec = by[s];
        var row = sec.index[title];
        if (!row) { row = sec.index[title] = { title: title, alts: [], hit: false }; sec.rows.push(row); }
        row.alts.push(keyCaps(b.keys));
        if (_matches(b, words)) row.hit = true;
    }
    var out = [];
    for (var j = 0; j < order.length; j++) {
        var rows = by[order[j]].rows.filter(function (r) { return r.hit; })
                                     .map(function (r) { return { title: r.title, alts: r.alts }; });
        if (rows.length) out.push({ section: order[j], rows: rows });
    }
    return out;
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
    var out = (base || []).map(function (b) { return b; });
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
