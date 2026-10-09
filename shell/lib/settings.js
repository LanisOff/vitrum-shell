.pragma library
// Settings: merge user values over shipped defaults, and drop what does not
// fit — a wrong type or an unknown enum value falls back to the default with
// a warning instead of taking the shell down.

function _isObj(v) { return v !== null && typeof v === "object" && !Array.isArray(v); }
function _type(v) { return v === null ? "null" : Array.isArray(v) ? "array" : typeof v; }

function deepMerge(base, over) {
    if (!_isObj(base) || !_isObj(over)) return over === undefined ? base : over;
    var out = {}, k;
    for (k in base) out[k] = base[k];
    for (k in over) out[k] = (_isObj(base[k]) && _isObj(over[k])) ? deepMerge(base[k], over[k]) : over[k];
    return out;
}

function get(obj, path, fallback) {
    var parts = String(path).split("."), cur = obj;
    for (var i = 0; i < parts.length; i++) {
        if (!_isObj(cur) && !Array.isArray(cur)) return fallback;
        cur = cur[parts[i]];
        if (cur === undefined) return fallback;
    }
    return cur;
}

function set(obj, path, value) {
    var out = JSON.parse(JSON.stringify(obj || {})), parts = String(path).split("."), cur = out;
    for (var i = 0; i < parts.length - 1; i++) {
        if (!_isObj(cur[parts[i]])) cur[parts[i]] = {};
        cur = cur[parts[i]];
    }
    cur[parts[parts.length - 1]] = value;
    return out;
}

function _enumFor(enums, path) {
    if (enums[path]) return enums[path];
    var parent = path.slice(0, path.lastIndexOf("."));
    return parent && enums[parent + ".*"] ? enums[parent + ".*"] : null;
}

function _check(user, defs, enums, prefix, warnings) {
    var out = {};
    for (var k in user) {
        var path = prefix ? prefix + "." + k : k, v = user[k], d = defs ? defs[k] : undefined;
        var allowed = _enumFor(enums, path);
        if (d === undefined && !allowed) { out[k] = v; continue; }           // unknown key: kept
        if (allowed && allowed.indexOf(v) < 0) {
            warnings.push(path + ": expected one of " + allowed.join(", ") + ", got " + JSON.stringify(v));
            continue;
        }
        if (d !== undefined && _type(v) !== _type(d)) {
            warnings.push(path + ": expected " + _type(d) + ", got " + JSON.stringify(v));
            continue;
        }
        if (_isObj(v)) {
            // A default of {} is a free-form map: check children only against wildcard enums.
            var hasKeys = d && Object.keys(d).length > 0;
            out[k] = _check(v, hasKeys ? d : {}, enums, path, warnings);
        } else {
            out[k] = v;
        }
    }
    return out;
}

function validate(user, defaults, enums) {
    var warnings = [];
    var value = _isObj(user) ? _check(user, defaults, enums || {}, "", warnings) : {};
    if (!_isObj(user) && user !== undefined) warnings.push("settings: expected an object");
    return { value: value, warnings: warnings };
}
