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
    readonly property int islandRadius: Math.round(islandHeight / 2)
    /// Spotlight's search capsule: an even 1.6 islands, so half of it (the
    /// radius vitrum-theme gives niri for it) is whole.
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
    readonly property int hairline: 1

    readonly property string fontPreset: Settings.get("fonts.preset", "sans")
    readonly property string fontText: fontPreset === "mono" ? Settings.get("fonts.nerd", "JetBrainsMono Nerd Font") : Settings.get("fonts.sans", "Inter")
    readonly property string fontMono: fontPreset === "mono" ? Settings.get("fonts.nerd", "JetBrainsMono Nerd Font") : Settings.get("fonts.mono", "JetBrains Mono")
    readonly property string fontIcons: "Material Symbols Rounded"
    readonly property string fontNerd: Settings.get("fonts.nerd", "JetBrainsMono Nerd Font")
}
