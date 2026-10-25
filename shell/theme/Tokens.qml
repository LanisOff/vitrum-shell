pragma Singleton

import QtQuick
import Quickshell
import qs.services

/*
 * Sizes and type, from the density and font settings. Modules use these and
 * nothing else — no literal pixel sizes anywhere in the shell.
 */
Singleton {
    readonly property string density: Settings.get("density", "compact")
    readonly property var _d: ({
        compact:     { island: 30, text: 12, small: 11, large: 15, title: 22, icon: 16, gap: 8,  pad: 10, panel: 20 },
        regular:     { island: 34, text: 13, small: 12, large: 16, title: 24, icon: 18, gap: 10, pad: 12, panel: 22 },
        comfortable: { island: 38, text: 14, small: 13, large: 17, title: 26, icon: 20, gap: 12, pad: 14, panel: 24 }
    })[density] || ({ island: 30, text: 12, small: 11, large: 15, title: 22, icon: 16, gap: 8, pad: 10, panel: 20 })

    readonly property int islandHeight: _d.island
    /// Spotlight's search field: an even 1.6 islands (as tall as a Tile). A
    /// rounded rectangle with radiusLauncher, the radius vitrum-theme gives
    /// niri for the launcher's glass.
    readonly property int launcherHeight: 2 * Math.round(islandHeight * 0.8)
    /// fonts.scale: text only — islands, panels and gaps follow the density.
    readonly property real textScale: Math.max(0.85, Math.min(1.3, Number(Settings.get("fonts.scale", 1)) || 1))
    readonly property int textSize: Math.round(_d.text * textScale)
    readonly property int textSmall: Math.round(_d.small * textScale)
    readonly property int textLarge: Math.round(_d.large * textScale)
    readonly property int textTitle: Math.round(_d.title * textScale)
    readonly property int iconSize: _d.icon
    readonly property int gap: _d.gap
    readonly property int padding: _d.pad
    readonly property int radiusPanel: _d.panel
    readonly property int radiusInner: Math.max(6, _d.panel - _d.pad)
    /// Radii of the small parts (dichroic glass: rounded, never capsules).
    /// Compact values; the other densities scale them with the panel radius
    /// (1, 1.1, 1.2). vitrum-theme mirrors radiusIsland and radiusLauncher
    /// into niri's effects.kdl (tools/vitrum_theme: RADIUS_SCALE), so niri's
    /// glass and the shell's tint keep the same corners.
    readonly property real _rs: _d.panel / 20
    readonly property int radiusTile: Math.round(12 * _rs)
    readonly property int radiusButton: Math.round(9 * _rs)
    readonly property int radiusIsland: Math.round(10 * _rs)
    readonly property int radiusSwitch: Math.round(8 * _rs)
    readonly property int radiusKnob: Math.round(6 * _rs)
    readonly property int radiusSlider: Math.round(11 * _rs)
    readonly property int radiusMeter: Math.round(3 * _rs)
    readonly property int radiusMark: Math.round(3 * _rs)
    /// Spotlight's search field and category buttons: a tile's corners.
    readonly property int radiusLauncher: radiusTile
    /// Every bar island (and Bar's pieceRadius/fillet): radiusIsland.
    readonly property int islandRadius: radiusIsland
    readonly property int hairline: 1

    readonly property string fontPreset: Settings.get("fonts.preset", "sans")
    readonly property string fontText: fontPreset === "mono" ? Settings.get("fonts.nerd", "JetBrainsMono Nerd Font") : Settings.get("fonts.sans", "Inter")
    readonly property string fontMono: fontPreset === "mono" ? Settings.get("fonts.nerd", "JetBrainsMono Nerd Font") : Settings.get("fonts.mono", "JetBrains Mono")
    readonly property string fontIcons: "Phosphor-Light"
    readonly property string fontIconsFill: "Phosphor-Fill"
    readonly property string fontNerd: Settings.get("fonts.nerd", "JetBrainsMono Nerd Font")
}
