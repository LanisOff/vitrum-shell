pragma Singleton

import QtQuick
import Quickshell
import "../lib/games.js" as Games

/*
 * Stay awake: no idle lock, no screen blanking, no sleep while it is on. On by
 * hand (until turned off, or for a while), and on by itself while a fullscreen
 * window plays a video or is a game (awake.auto) and while anything plays
 * (awake.media). The bar's IdleInhibitor
 * holds the actual inhibit; the idle monitor respects it.
 */
Singleton {
    id: root

    /// "off" | "on" (until turned off) | "timed" (until `until`)
    property string mode: "off"
    property real until: 0
    property real now: Date.now()

    readonly property bool manual: mode === "on" || (mode === "timed" && now < until)
    readonly property var fullscreen: Niri.fullscreenWindow
    readonly property bool automatic: Settings.get("awake.auto", true) && fullscreen !== null
        && (Media.playing || Games.isGame(fullscreen, Settings.get("games.extra", [])))
    /// Anything playing keeps it awake (awake.media), fullscreen or not.
    readonly property bool media: Settings.get("awake.media", true) && Media.playing
    readonly property bool active: manual || automatic || media
    /// Seconds left in timed mode.
    readonly property int remaining: mode === "timed" ? Math.max(0, Math.ceil((until - now) / 1000)) : 0

    function setOn() { mode = "on"; }
    function setOff() { mode = "off"; }
    function setFor(minutes) { until = Date.now() + minutes * 60000; now = Date.now(); mode = "timed"; }
    /// The chip's tap: off → on → off.
    function toggle() { if (manual) setOff(); else setOn(); }

    Timer {
        running: root.mode === "timed"
        interval: 1000; repeat: true; triggeredOnStart: true
        onTriggered: { root.now = Date.now(); if (root.now >= root.until) root.mode = "off"; }
    }
}
