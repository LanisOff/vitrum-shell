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

    /// Glass on this group, drawn by niri in the shape of the region's pieces.
    function shaped(group) { return shapedGlass && of(group) === "glass"; }

    function of(group) {
        const g = Settings.get("materials.groups", {});
        return g[group] || Settings.get("materials.default", "frosted");
    }
    // No blur while a game runs: niri draws no effects for the shell then.
    function wantsRegion(group) { return of(group) !== "solid" && !GameMode.active; }

    // level: 0 base, 1 raised (inner cards), 2 highest
    function fill(group, level) {
        const m = of(group);
        const base = level >= 2 ? Colors.surfaceHighest : level === 1 ? Colors.surfaceHigh : Colors.surface;
        if (m === "solid") return base;
        if (m === "glass") return Colors.alpha(base, level === 0 ? 0.10 : 0.22);
        return Colors.alpha(base, level === 0 ? 0.62 : 0.72);
    }
    function border(group) {
        return of(group) === "solid" ? Colors.alpha(Colors.outline, 0.6) : Colors.alpha(Colors.text, 0.08);
    }
}
