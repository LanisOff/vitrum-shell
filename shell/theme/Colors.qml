pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

/*
 * The colours, from ~/.local/share/vitrum/palette.json (written by
 * vitrum-theme), in the current scheme. Until that file exists the graphite
 * preset shipped with the shell is used. Role changes animate (see Motion).
 */
Singleton {
    id: root

    readonly property string mode: Settings.get("scheme.mode", "auto")
    readonly property string scheme: mode === "light" || mode === "dark" ? mode : (Sun.isDay ? "light" : "dark")
    readonly property bool dark: scheme === "dark"

    property var _file: null
    property var _fallback: null
    readonly property var _roles: ((_file || _fallback || {})[scheme]) || ({})

    function _c(role, fallback) { return _roles[role] || fallback; }

    readonly property color bg:             _c("bg", "#0e0f11")
    readonly property color surface:        _c("surface", "#1b1d21")
    readonly property color surfaceHigh:    _c("surfaceHigh", "#24272c")
    readonly property color surfaceHighest: _c("surfaceHighest", "#2e3238")
    readonly property color outline:        _c("outline", "#3c4148")
    readonly property color text:           _c("text", "#e6e8eb")
    readonly property color textDim:        _c("textDim", "#a3a9b1")
    readonly property color accent:         _c("accent", "#8ab4f8")
    readonly property color onAccent:       _c("onAccent", "#0b1f3f")
    readonly property color danger:         _c("danger", "#f28b82")
    readonly property color warning:        _c("warning", "#fdd663")
    readonly property color success:        _c("success", "#81c995")

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    /// The accent turned `degrees` round the colour wheel, at a widget plate's
    /// saturation and lightness (`lift` lightens or darkens it): a family of
    /// colours that all come from the wallpaper.
    function tone(degrees, lift) {
        const h = ((accent.hslHue < 0 ? 0 : accent.hslHue) + degrees / 360 + 1) % 1;
        const s = Math.max(0.42, Math.min(0.72, accent.hslSaturation));
        const l = (dark ? 0.40 : 0.58) + (lift || 0);
        return Qt.hsla(h, s, Math.max(0.05, Math.min(0.95, l)), 1);
    }
    /// The same family, for data drawn on glass (rings, graphs, icons):
    /// lighter in the dark, deeper in the light, and a little more vivid.
    /// A fixed hue (0..1) at data lightness, for colours that carry meaning
    /// whatever the wallpaper: sun warm, rain blue, heat orange.
    function meaning(hue) {
        return Qt.hsla(hue, 0.72, dark ? 0.66 : 0.44, 1);
    }
    function ink(degrees) {
        const h = ((accent.hslHue < 0 ? 0 : accent.hslHue) + degrees / 360 + 1) % 1;
        const s = Math.max(0.5, Math.min(0.8, accent.hslSaturation + 0.08));
        return Qt.hsla(h, s, dark ? 0.68 : 0.42, 1);
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/share/vitrum/palette.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root._file = JSON.parse(text()).palette; } catch (e) { root._file = null; } }
        onLoadFailed: root._file = null
    }
    FileView {
        path: Qt.resolvedUrl("../data/palettes.json").toString().replace("file://", "")
        onLoaded: root._fallback = JSON.parse(text()).graphite
    }
}
