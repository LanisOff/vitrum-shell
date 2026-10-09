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
