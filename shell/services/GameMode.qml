pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/games.js" as Games

/*
 * Game mode: on while a game fills the screen (a Steam game, gamescope, or one
 * from games.extra), or by hand. While it is on the shell stays out of the
 * way — no animations, no blur, notifications held back (critical ones still
 * show; the rest arrive as one summary afterwards) — the game is registered
 * with gamemode (CPU governor, priorities), and MangoHud shows its HUD.
 */
Singleton {
    id: root

    /// Turned on by hand (Control Centre), for games the rules do not know.
    property bool forced: false
    readonly property var extra: Settings.get("games.extra", [])
    readonly property var game: {
        const w = Niri.fullscreenWindow;
        return w && Games.isGame(w, extra) ? w : null;
    }
    readonly property bool active: Settings.get("games.mode", true) && (game !== null || forced)
    property int registeredPid: 0

    // The Settings app shares this code (and Motion reads it): only the shell acts.
    readonly property bool inShell: !Quickshell.env("VITRUM_NO_THEME")
    onGameChanged: if (inShell) _register()
    onActiveChanged: {
        if (!inShell) return;
        _register();
        if (active && Settings.get("games.hud", true)) hud(true);
    }

    // gamemode: register the game's process (it was started without gamemoderun).
    function _register() {
        const pid = active && game ? (Niri.windowPid(game.id) || 0) : 0;
        if (pid === registeredPid) return;
        if (registeredPid) _gm("UnregisterGameByPID", registeredPid);
        if (pid) _gm("RegisterGameByPID", pid);
        registeredPid = pid;
    }
    function _gm(method, pid) {
        Quickshell.execDetached(["gdbus", "call", "--session", "--dest", "com.feralinteractive.GameMode",
                                 "--object-path", "/com/feralinteractive/GameMode",
                                 "--method", "com.feralinteractive.GameMode." + method,
                                 String(Quickshell.processId), String(pid)]);
    }

    /// MangoHud in the running game: shown or hidden (mangohudctl; the HUD is
    /// loaded hidden into every Vulkan game, see games.hud).
    function hud(show) { Quickshell.execDetached(["mangohudctl", "set", "no_display", show ? "0" : "1"]); }
    function toggleHud() { Quickshell.execDetached(["mangohudctl", "toggle", "no_display"]); }
}
