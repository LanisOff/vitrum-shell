.pragma library
// The Settings app's helpers: labels for keys, the allowed values of a key,
// every key there is, and the check behind the Advanced (raw JSON) pane.

// "wallpaper.live.pauseWhenCovered" → "Pause when covered"
function label(key) {
    var last = String(key).split(".").pop();
    var words = last.replace(/([a-z0-9])([A-Z])/g, "$1 $2").toLowerCase();
    return words.charAt(0).toUpperCase() + words.slice(1);
}

// The enum list for a key; "a.b.*" entries match any last segment.
function options(enums, key) {
    if (enums[key]) return enums[key];
    var parts = String(key).split(".");
    parts[parts.length - 1] = "*";
    return enums[parts.join(".")] || [];
}

function _isObj(v) { return v !== null && typeof v === "object" && !Array.isArray(v); }

// Every settable key: objects are walked; lists and empty objects are one key each.
function leafKeys(obj, prefix) {
    var out = [];
    for (var k in obj) {
        var p = prefix ? prefix + "." + k : k, v = obj[k];
        if (_isObj(v) && Object.keys(v).length) out = out.concat(leafKeys(v, p));
        else out.push(p);
    }
    return out;
}

// text → { ok, errors, warnings, value }. validate(raw) is settings.js's
// validate bound to the defaults and enums. Only an object that parses is ok;
// wrong types inside it are warnings (those keys fall back to defaults).
function checkRaw(text, validate) {
    var raw;
    if (!String(text).trim()) raw = {};
    else {
        try { raw = JSON.parse(text); }
        catch (e) {
            var m = /position (\d+)/.exec(String(e.message)), where = "";
            if (m) where = " (line " + (String(text).slice(0, Number(m[1])).split("\n").length) + ")";
            return { ok: false, errors: ["Not valid JSON" + where + ": " + e.message], warnings: [], value: null };
        }
    }
    if (!_isObj(raw)) return { ok: false, errors: ["The settings must be one JSON object { … }"], warnings: [], value: null };
    var r = validate(raw);
    return { ok: true, errors: [], warnings: r.warnings, value: r.value };
}
