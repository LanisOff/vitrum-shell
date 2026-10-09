.pragma library
// The overview overlay: the window filter and the workspace rail.

// windows: most recent first; names: appId → application name. Matches on the
// app (id or name) come before matches on the title only; order within each
// stays most-recent-first.
function filter(windows, query, names) {
    var q = (query || "").trim().toLowerCase();
    if (!q) return windows.slice();
    var byApp = [], byTitle = [];
    for (var i = 0; i < windows.length; i++) {
        var w = windows[i], id = (w.appId || "").toLowerCase(), name = ((names || {})[w.appId] || "").toLowerCase();
        if (id.indexOf(q) >= 0 || name.indexOf(q) >= 0) byApp.push(w);
        else if ((w.title || "").toLowerCase().indexOf(q) >= 0) byTitle.push(w);
    }
    return byApp.concat(byTitle);
}

function rail(spaces, windows) {
    return spaces.map(function (s) {
        var n = 0;
        for (var i = 0; i < windows.length; i++) if (windows[i].workspaceId === s.id) n++;
        return { id: s.id, idx: s.idx, label: String(s.idx) + (s.name ? " · " + s.name : ""), count: n, active: !!s.active };
    });
}
