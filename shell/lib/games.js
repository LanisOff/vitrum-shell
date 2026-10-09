.pragma library
// What is a game, and is a window fullscreen. Game mode and the stay-awake
// mode turn on for a fullscreen game; niri has no fullscreen flag, so a window
// as big as its output counts.

var GAME_IDS = [/^steam_app_\d+$/, /^gamescope$/i];

// win: {appId, title}; extra: the user's list (substrings of app id or title).
function isGame(win, extra) {
    if (!win) return false;
    var id = win.appId || "", title = win.title || "";
    for (var i = 0; i < GAME_IDS.length; i++) if (GAME_IDS[i].test(id)) return true;
    var hay = (id + "\n" + title).toLowerCase();
    var list = extra || [];
    for (var j = 0; j < list.length; j++) {
        var s = String(list[j] || "").toLowerCase().trim();
        if (s && hay.indexOf(s) >= 0) return true;
    }
    return false;
}

// win: a niri window (with layout.window_size); output: {width, height} logical.
function isFullscreen(win, output) {
    if (!win || !output || !win.layout || !win.layout.window_size) return false;
    var s = win.layout.window_size;
    return Math.abs(s[0] - output.width) <= 1 && Math.abs(s[1] - output.height) <= 1;
}
