.pragma library
// overrides.kdl may carry its own mouse { } / touchpad { } block; niri does not
// merge pointer sections, so then Settings → Mouse & touchpad has no effect.

function _strip(text) {
    return String(text || "").replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/[^\n]*/g, "");
}

function overridden(text) {
    var t = _strip(text);
    return { mouse: /(^|[\s{;])mouse\s*\{/.test(t), touchpad: /(^|[\s{;])touchpad\s*\{/.test(t) };
}
