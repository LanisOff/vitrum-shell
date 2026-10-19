pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

/*
 * Materials per surface group: solid, frosted (default) or glass. niri draws
 * the blur/glass (vitrum-theme writes the rules); the shell paints the fill
 * on top and asks for the effect region on frosted and glass surfaces.
 */
Singleton {
    id: root
    // What the running niri can do (vitrum-theme probes it): shaped glass.
    property bool shapedGlass: false
    FileView {
        path: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/vitrum/niri-caps.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.shapedGlass = !!JSON.parse(text()).shapedGlass; } catch (e) { root.shapedGlass = false; } }
        onLoadFailed: root.shapedGlass = false
    }

    /// While a game runs, on the game's screen: no blur and no glass from niri
    /// (wantsRegion, shaped), plain translucent fills instead — they read over
    /// the game, and niri has nothing to sample and bend behind them on its
    /// frames. The other screens keep their material: a still screen costs
    /// nothing. screen: the surface's screen name; not known (or game mode on
    /// by hand, no game found): plain. The lock draws its own glass, over its
    /// own picture, and keeps it.
    function plain(group, screen) {
        return GameMode.active && group !== "lock" && (!screen || !GameMode.screen || screen === GameMode.screen);
    }

    /// Glass on this group, drawn by niri in the shape of the region's pieces.
    function shaped(group, screen) { return shapedGlass && of(group) === "glass" && !plain(group, screen); }

    function of(group) {
        const g = Settings.get("materials.groups", {});
        return g[group] || Settings.get("materials.default", "frosted");
    }
    function wantsRegion(group, screen) { return of(group) !== "solid" && !plain(group, screen); }

    // level: 0 base, 1 raised (inner cards), 2 highest
    function fill(group, level, screen) {
        const m = of(group);
        const base = level >= 2 ? Colors.surfaceHighest : level === 1 ? Colors.surfaceHigh : Colors.surface;
        if (m === "solid") return base;
        if (plain(group, screen)) return Colors.alpha(base, level === 0 ? 0.86 : 0.92);
        if (m === "glass") return Colors.alpha(base, level === 0 ? 0.10 : 0.22);
        return Colors.alpha(base, level === 0 ? 0.62 : 0.72);
    }
    function border(group) {
        return of(group) === "solid" ? Colors.alpha(Colors.outline, 0.6) : Colors.alpha(Colors.text, 0.08);
    }
}
