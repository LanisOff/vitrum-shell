import QtQuick
import qs.services
import qs.theme

/*
 * The dichroic tint (Tint) in the shell's theme: `tint` (the accent by
 * default) and its pair (Colors.pair: accent2 for the accent, the same colour
 * turned −30° and lighter for any other), the scheme, and the drift only when
 * Motion.enabled, not held still by lite mode (Lite.lightOff) and not over a
 * game (Materials.overGame): a tint there is drawn, but never moves.
 *
 *     ShellTint { anchors.fill: parent; radius: Tokens.radiusTile; active: root.active; hovered: mouse.containsMouse }
 */
Tint {
    /// The colour the tint starts from (danger for a destructive button).
    property color tint: Colors.accent
    /// The material group of the piece it lies on (for game mode's plain).
    property string group: "panels"

    color: tint
    color2: Colors.pair(tint)
    dark: Colors.dark
    animate: Motion.enabled && !Lite.lightOff && !Materials.overGame(group, Screen.name)
    duration: Motion.drift
    sweepDuration: Motion.sweep
    fadeDuration: Motion.emphasized
    Behavior on color { enabled: Motion.enabled; ColorAnim {} }
    Behavior on color2 { enabled: Motion.enabled; ColorAnim {} }
}
