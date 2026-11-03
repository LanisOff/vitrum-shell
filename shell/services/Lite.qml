pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/lite.js" as Lib

/*
 * Lite mode: the heavy effects cut, for a slow machine or a long way from a
 * charger (Settings → Lite mode). One place says what is cut; the rest of the
 * shell reads these and nothing else:
 *
 *   blurOff              Materials.plain: plain translucent fills, no blur region
 *   glassOff             Materials.of: glass reads as frosted (no shaped glass,
 *                        no refraction); the desktop clock's digits are painted
 *   lightOff             ShellTint, Motion.drift/sweep: lit glass holds still
 *   animationsOff        Motion.enabled and every duration (0)
 *   shadowsOff           the desktop clock's and its glass's shadows
 *   stillWallpaper       Wallpaper.live and .parallax: a still image
 *   spectrumOff          Cava never runs
 *   slowPolling          poll(ms): SysInfo, the GPU loop, Network, the widgets…
 *   windowAnimationsOff, windowGlassOff: niri's alone (vitrum-theme)
 *
 * The master switch (lite.enabled) or an automatic reason (on battery, a low
 * battery, the Saver profile) cuts them all; otherwise each follows its own
 * switch. niri's part is written by vitrum-theme from the settings; the
 * automatic reason, which only the shell knows, goes to it through
 * ~/.local/share/vitrum/lite, and a change of it re-runs vitrum-theme.
 */
Singleton {
    id: root

    readonly property var conf: Settings.get("lite", ({}))
    readonly property var r: Lib.resolve(conf, {
        hasBattery: Power.hasBattery,
        pluggedIn: Power.pluggedIn,
        percentage: Power.percentage,
        saver: Power.profile === "power-saver"
    })

    /// Everything cut: the master switch or an automatic reason.
    readonly property bool active: r.active
    /// "manual", "battery", "low", "saver", or "" (off).
    readonly property string reason: r.reason

    readonly property bool blurOff: r.cut.blur
    readonly property bool glassOff: r.cut.glass
    readonly property bool lightOff: r.cut.light
    readonly property bool animationsOff: r.cut.animations
    readonly property bool windowAnimationsOff: r.cut.windowAnimations
    readonly property bool shadowsOff: r.cut.shadows
    readonly property bool stillWallpaper: r.cut.wallpaper
    readonly property bool spectrumOff: r.cut.spectrum
    readonly property bool windowGlassOff: r.cut.windowGlass
    readonly property bool slowPolling: r.cut.polling

    /// A polling interval in ms, three times longer with slowPolling.
    function poll(ms) { return Lib.interval(ms, slowPolling); }
    // Power is read above, and reads GameMode, which reads Niri: they are told,
    // and do not read Lite back.
    Binding { target: Power; property: "slowPolling"; value: root.slowPolling }
    Binding { target: Niri; property: "slowPolling"; value: root.slowPolling }

    // ------------------------------------------------- for vitrum-theme --
    // Only the shell writes it (the Settings app shares this file); after the
    // reason has held a moment, so plugging in and out again, or UPower
    // settling at start, does not reload niri's config each time.
    readonly property bool inShell: !Quickshell.env("VITRUM_NO_THEME")
    readonly property string stateText: Lib.stateText(r)
    property string _written: ""
    FileView {
        id: stateFile
        path: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/vitrum/lite"
        blockLoading: true
        blockWrites: true
        printErrors: false
        // What a run before this one left: unchanged, nothing to re-theme.
        onLoaded: root._written = text()
    }
    onStateTextChanged: if (inShell && Settings.ready) settle.restart()
    Connections { target: Settings; function onReadyChanged() { if (root.inShell && Settings.ready) settle.restart(); } }
    Timer {
        id: settle
        interval: 2000
        onTriggered: {
            if (root.stateText === root._written) return;
            root._written = root.stateText;
            stateFile.setText(root.stateText);
            Settings.retheme();
        }
    }
}
