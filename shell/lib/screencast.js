.pragma library
// The screen-share picker's decisions: what an answer looks like, and what to
// remember per app so the next request from it is answered without asking.

// A picked tile → the source the portal gets.
function sourcesOf(items) {
    return items.map(function (it) {
        return it.kind === "monitor" ? { type: "monitor", connector: it.name } : { type: "window", id: it.win.id };
    });
}

// A tile → what is remembered for the app: a screen by its connector, a window
// by its app (window ids do not survive a restart).
function entryFor(item, cursor) {
    return item.kind === "monitor" ? { type: "monitor", connector: item.name, cursor: !!cursor }
                                    : { type: "window", appId: item.win.appId, cursor: !!cursor };
}

// The answer for req ({app, types}) from what was remembered, when that is
// still there and allowed this time; null means: ask.
function rememberedAnswer(remember, req, screens, windows) {
    if (!remember || !req || !req.app) return null;
    var e = remember[req.app];
    if (!e) return null;
    var cursor = e.cursor !== false;
    if (e.type === "monitor" && (req.types & 1)) {
        for (var i = 0; i < screens.length; i++)
            if (screens[i].name === e.connector) return { ok: true, cursor: cursor, sources: [{ type: "monitor", connector: e.connector }] };
    }
    if (e.type === "window" && (req.types & 2)) {
        var best = null;
        for (var j = 0; j < windows.length; j++) {
            var w = windows[j];
            if (w.appId === e.appId && (!best || (w.focusTime || 0) > (best.focusTime || 0))) best = w;
        }
        if (best) return { ok: true, cursor: cursor, sources: [{ type: "window", id: best.id }] };
    }
    return null;
}

// For the toast: "DP-2", "a kitty window", "2 sources".
function describe(answer, windows) {
    var s = answer.sources || [];
    if (s.length !== 1) return s.length + " sources";
    if (s[0].type === "monitor") return s[0].connector;
    for (var i = 0; i < windows.length; i++) if (windows[i].id === s[0].id) return "a " + (windows[i].appId || "window") + " window";
    return "a window";
}
