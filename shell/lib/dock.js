.pragma library
// Intellihide: the dock hides only when a window actually reaches into it.

function overlaps(dock, tiles) {
    for (var i = 0; i < (tiles || []).length; i++) {
        var t = tiles[i];
        if (t.x < dock.x + dock.w && t.x + t.w > dock.x && t.y < dock.y + dock.h && t.y + t.h > dock.y) return true;
    }
    return false;
}

function intellihideVisible(s) {
    return !!(s.hovered || s.dragging || s.settingsMode || !s.overlapping);
}

// The dock's items: pinned apps in the user's order, then running apps that
// are not pinned, in the order they were first seen. Windows match an app id
// case-insensitively.
function items(pinned, windows) {
    var out = [], index = {};
    function key(s) { return String(s || "").toLowerCase(); }
    (pinned || []).forEach(function (id) {
        index[key(id)] = out.length;
        out.push({ appId: id, pinned: true, windows: [], focused: false });
    });
    (windows || []).forEach(function (w) {
        var k = key(w.appId);
        if (!k) return;
        if (index[k] === undefined) { index[k] = out.length; out.push({ appId: w.appId, pinned: false, windows: [], focused: false }); }
        var e = out[index[k]];
        e.windows.push(w);
        if (w.focused) e.focused = true;
    });
    return out;
}
