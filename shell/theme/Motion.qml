pragma Singleton

import QtQuick
import Quickshell
import qs.services
import "../lib/motion.js" as M

/*
 * Motion tokens. Springs (ζ, k) — the same pairs vitrum-theme gives niri — for
 * anything that moves or resizes; eased durations for opacity and colour.
 * Use the components in components/ (SpringAnim, EaseAnim, ColorAnim).
 */
Singleton {
    readonly property real speed: Math.max(0.1, Settings.get("motion.speed", 1.0))
    readonly property bool reduce: Settings.get("motion.reduce", false)
    // No animations while a game runs (GameMode): the shell keeps out of its way.
    readonly property bool enabled: !reduce && !GameMode.active

    readonly property var snappy: M.qtSpring(1.0, 900 * speed * speed)
    readonly property var smooth: M.qtSpring(1.0, 600 * speed * speed)
    readonly property var bouncy: M.qtSpring(0.75, 520 * speed * speed)

    readonly property int fast: M.scaled(150, speed, reduce)
    readonly property int standard: M.scaled(240, speed, reduce)
    readonly property int emphasized: M.scaled(380, speed, reduce)
    readonly property int colour: M.scaled(300, speed, reduce)
}
