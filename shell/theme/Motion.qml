pragma Singleton

import QtQuick
import Quickshell
import qs.services
import "../lib/motion.js" as M

/*
 * Motion tokens. Springs (ζ, k) — the same pairs vitrum-theme gives niri — for
 * anything that moves or resizes; eased durations for opacity and colour.
 * Every spring is critically damped: no bounce, no overshoot anywhere (and no
 * Easing.OutBack: use OutCubic or OutQuint). Use the components in
 * components/ (SpringAnim, EaseAnim, ColorAnim).
 */
Singleton {
    readonly property real speed: Math.max(0.1, Settings.get("motion.speed", 1.0))
    readonly property bool reduce: Settings.get("motion.reduce", false)
    // No animations while a game runs (GameMode): the shell keeps out of its way.
    readonly property bool enabled: !reduce && !GameMode.active

    readonly property var snappy: M.spring("snappy", speed)
    readonly property var smooth: M.spring("smooth", speed)
    /// deprecated alias, kept for user widgets: the springs have no bounce now.
    readonly property var bouncy: smooth

    readonly property int fast: M.scaled(150, speed, reduce)
    readonly property int standard: M.scaled(240, speed, reduce)
    readonly property int emphasized: M.scaled(380, speed, reduce)
    readonly property int colour: M.scaled(300, speed, reduce)
    /// The dichroic tint's drift under the pointer (Tint): ~1.2 s, damped.
    readonly property int drift: M.scaled(M.DRIFT_MS, speed, reduce)
    /// The one sweep across a tint that turns on: ~1 s, damped.
    readonly property int sweep: M.scaled(M.SWEEP_MS, speed, reduce)
    readonly property var glide: M.GLIDE
    /// A meter (0..1) moves to a new value only for a step this big; a smaller
    /// one is set at once. Live figures change a little with every sample, and
    /// any animation starting wakes every window of the shell for a frame.
    readonly property real meterStep: 0.04
}
