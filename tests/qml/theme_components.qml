import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components

ShellRoot {
    id: root
    function check(name, ok, why) { console.log((ok ? " PASS " : " FAIL ") + name + (ok ? "" : ": " + why)); }
    /// The first item under `item` (depth first) for which `test` holds.
    function find(item, test) {
        for (const c of item.children) {
            if (test(c)) return c;
            const f = find(c, test);
            if (f) return f;
        }
        return null;
    }
    Component.onCompleted: Settings.ready

    // Instantiate every component off-screen.
    Item {
        id: host
        Island { id: island; Label { text: "12:34"; numeric: true } Icon { name: "wifi" } }
        Capsule { id: cap; icon: "lock"; label: "Lock" }
        Chip { id: chip; icon: "bluetooth"; title: "Bluetooth"; subtitle: "Off"; hasMenu: true }
        Slider { id: slider; value: 0.4 }
        Toggle { id: toggle; checked: true }
        GlassButton { id: btn; label: "Save"; primary: true }
        GlassButton { id: btnIcon; icon: "close" }
        GlassButton { id: btnOff; label: "Default"; primary: true; enabled: false; labelSize: Tokens.textSmall + 1 }
        GlassChoice { id: choice; label: "Daily"; chosen: true }
        GlassChoice { id: choiceIcon; icon: "wifi" }
        Slider { id: sliderBare; icon: ""; value: 0; width: 200 }
        Meter { id: meterWidget; value: 0.5; width: 100; group: "widgets" }
        Capsule { id: capDanger; label: "Delete"; active: true; color: Colors.danger }
        Tile { id: tile; icon: "wifi"; title: "Wi-Fi"; active: true }
        GlassSwitch { id: sw }
        GlassSwitch { id: swOn; checked: true }
        Meter { id: meter; value: 0.5; width: 100 }
        Meter { id: meterWarn; value: 0.9; width: 100; color: Colors.danger }
        Ring { id: ring; width: 56; height: 56; value: 0.3 }
        WidgetHeader { id: header; icon: "cpu"; title: "CPU" }
        Tint { id: plainTint; width: 80; height: 30; radius: 9 }
        ShellTint { id: shellTint; width: 80; height: 30; radius: 9; active: false }
        ShellTint { id: sweepTint; width: 80; height: 30; radius: 9; active: false }
        ShellTint { id: hoverTint; width: 80; height: 30; radius: 9; active: true }
        Card { id: card; Label { text: "x" } }
        Surface { id: glassy; group: "launcher" }
        // The bar defaults to glass (settings.defaults.json); panels follow the default, solid here.
        Surface { id: solidy; group: "panels" }
    }

    // Switching on: the tint fades in and a light passes once; hovered, its light slides to the far side.
    property var mid: ({})
    Timer {
        interval: 600; running: true
        onTriggered: { sweepTint.active = true; hoverTint.hovered = true; midShot.start(); }
    }
    Timer {
        id: midShot; interval: 300
        onTriggered: root.mid = { sweep: sweepTint._sweep, sweeping: sweepTint._sweeping, opacity: sweepTint.opacity, drift: hoverTint.drift }
    }

    Timer {
        interval: 2500; running: true
        onTriggered: {
            check("density comfortable → island 38", Tokens.islandHeight === 38, Tokens.islandHeight);
            // Dichroic glass: no capsules; small radii are tokens scaled 1.2 at comfortable.
            check("island radius is the island token, not half the island", Tokens.islandRadius === Tokens.radiusIsland && Tokens.radiusIsland === 12, Tokens.islandRadius);
            check("radius tokens scale with density", Tokens.radiusTile === 14 && Tokens.radiusButton === 11 && Tokens.radiusSwitch === 10
                  && Tokens.radiusKnob === 7 && Tokens.radiusSlider === 13 && Tokens.radiusMeter === 4 && Tokens.radiusMark === 4 && Tokens.radiusLauncher === 14,
                  [Tokens.radiusTile, Tokens.radiusButton, Tokens.radiusSwitch, Tokens.radiusKnob, Tokens.radiusSlider, Tokens.radiusMeter, Tokens.radiusMark, Tokens.radiusLauncher].join(","));
            check("island uses the token", island.radius === Tokens.islandRadius, island.radius);
            check("button and tile radii", btn.radius === Tokens.radiusButton && tile.radius === Tokens.radiusTile && cap.radius === Tokens.radiusButton, btn.radius + " " + tile.radius);
            check("an icon button is square", btnIcon.implicitWidth === btnIcon.implicitHeight, btnIcon.implicitWidth + "x" + btnIcon.implicitHeight);
            // accent2: hue + shift (−100°), saturation 0.72, lightness 0.42 in the light scheme.
            const dh = ((Colors.accent2.hslHue - Colors.accent.hslHue) * 360 + 720) % 360;
            check("accent2 is the accent turned −100°", Math.abs(dh - 260) < 2, dh);
            check("accent2 light lightness", Math.abs(Colors.accent2.hslLightness - 0.42) < 0.02 && Math.abs(Colors.accent2.hslSaturation - 0.72) < 0.03, Colors.accent2);
            check("pair of the accent is accent2", Qt.colorEqual(Colors.pair(Colors.accent), Colors.accent2), Colors.pair(Colors.accent));
            const pd = ((Colors.pair(Colors.danger).hslHue - Colors.danger.hslHue) * 360 + 720) % 360;
            check("a meaning colour keeps its family (−30°)", Math.abs(pd - 330) < 2, pd);
            check("meter default pair", Qt.colorEqual(meter.color2, Colors.accent2), meter.color2);
            check("warning meter stays red", Qt.colorEqual(meterWarn.color, Colors.danger) && !Qt.colorEqual(meterWarn.color2, Colors.accent2), meterWarn.color2);
            check("danger button tints from danger", Qt.colorEqual(capDanger.tint, Colors.danger) && capDanger.primary, capDanger.tint);
            check("deprecated aliases keep their API", cap.active === false && chip.hasMenu && toggle.checked && typeof toggle.toggled === "function", "");
            check("toggle is the 38x22 switch scaled", toggle.implicitWidth === Math.round(38 * Tokens.islandHeight / 30) && toggle.implicitHeight === Math.round(22 * Tokens.islandHeight / 30), toggle.implicitWidth + "x" + toggle.implicitHeight);
            check("a tint at rest does not drift", plainTint.drift === 0 && plainTint._pos === 0 && !plainTint._sweeping, plainTint._pos);
            // Lit glass: a white frost, the colour only a light under the piece, its lightness capped.
            check("a control's glass carries no colour, only frost", plainTint.alphaMiddle === 0 && plainTint.alphaEnd === 0 && plainTint._frostKeep === 1
                  && plainTint._frostTop > plainTint._frostBottom, plainTint._frostTop + " " + plainTint._frostBottom);
            check("the light under a piece is capped in lightness (dark ≤ 0.62)", plainTint._glow.hslLightness <= 0.625 && plainTint.color.hslLightness > 0.7, plainTint._glow);
            check("the light is deeper in the light scheme (≤ 0.55)", hoverTint._glow.hslLightness <= 0.555 && hoverTint.alphaStart > 0, hoverTint._glow);
            const swTint = find(swOn, c => c.alphaMiddle !== undefined && c.sweep !== undefined);
            check("an on switch's track is lit glass with a faint wash, no light under it", swTint && swTint.alphaStart === 0 && swTint.alphaMiddle > 0 && swTint.alphaMiddle <= 0.18
                  && Qt.colorEqual(swTint.color2, swTint.color), swTint ? swTint.alphaStart + " " + swTint.alphaMiddle : "no tint");
            const meterTint = find(meter, c => c.alphaMiddle !== undefined && c.sweep !== undefined);
            check("a meter keeps colour in its glass", meterTint && meterTint.alphaMiddle > 0.3 && meterTint._frostKeep < 1, meterTint ? meterTint.alphaMiddle : "no tint");
            const sliderFill = find(sliderBare, c => c.alphaMiddle !== undefined && c.sweep !== undefined);
            check("a slider is a rounded rect, never a stadium, and its fill shrinks to a sliver", sliderBare.radius < (sliderBare.height - 2 * sliderBare.inset) / 2 - 1
                  && sliderFill && sliderFill.width <= 2 * sliderBare.radius + 0.5, sliderBare.radius + " " + (sliderFill ? sliderFill.width : "no fill"));
            const tileGlyph = find(tile, c => c.name === "wifi");
            check("an on tile's icon takes the tint's colour", tileGlyph && Qt.colorEqual(tileGlyph.color, tile.tint), tileGlyph ? tileGlyph.color : "no icon");
            const choiceGlyph = find(choiceIcon, c => c.name === "wifi");
            check("an unchosen choice's icon stays the text colour", choiceGlyph && Qt.colorEqual(choiceGlyph.color, Colors.text), choiceGlyph ? choiceGlyph.color : "no icon");
            check("an inactive tint is hidden", !shellTint.visible || shellTint.opacity === 0, shellTint.opacity);
            check("motion is on in the test", Motion.enabled && sweepTint.animate, Motion.enabled + " " + sweepTint.animate);
            check("switching on fades the tint in and sweeps it", root.mid.sweep > 0 && root.mid.sweep < 1 && root.mid.sweeping && root.mid.opacity > 0 && root.mid.opacity < 1, JSON.stringify(root.mid));
            check("the sweep runs once and rests", sweepTint._sweep === 0 && !sweepTint._sweeping && sweepTint.opacity === 1 && sweepTint._pos === 0, sweepTint._sweep + " " + sweepTint.opacity);
            check("hover slides the light to the far side", root.mid.drift > 0 && root.mid.drift < 1 && hoverTint.drift === 1 && hoverTint._pos === 1, root.mid.drift + " " + hoverTint.drift);
            check("no bouncy spring", Motion.bouncy.damping === Motion.smooth.damping, Motion.bouncy.damping);
            check("motion drift and sweep tokens", Motion.drift === 1200 && Motion.sweep === 1000, Motion.drift + " " + Motion.sweep);
            check("scheme forced light", Colors.scheme === "light" && !Colors.dark, Colors.scheme);
            check("fallback palette (no palette.json) is graphite light", Colors.surface.toString() === "#ffffff", Colors.surface);
            check("glass group fill is translucent", glassy.color.a < 0.3, glassy.color.a);
            check("solid group fill is opaque", solidy.color.a === 1, solidy.color.a);
            check("island sizes to content", island.implicitWidth > 2 * Tokens.padding + 20, island.implicitWidth);
            check("icons map loaded", Icons.glyph("wifi").font === "phosphor" && Icons.glyph("wifi").text === "\ue4ea", JSON.stringify(Icons.glyph("wifi")));
            check("mono preset falls back for missing nerd glyph", Icons.glyph("network-off").font === "phosphor", "");
            check("springs scale with speed", Motion.smooth.spring === 6, Motion.smooth.spring);
            check("button labelSize defaults to the text size", btn.labelSize === Tokens.textSize && btnOff.labelSize === Tokens.textSmall + 1, btn.labelSize + " " + btnOff.labelSize);
            check("a disabled button dims and stays still", btnOff.opacity < 0.5 && !btnOff.hovered && !btnOff.pressed, btnOff.opacity);
            check("choice: the shared chip", choice.radius === Tokens.radiusButton && choice.chosen && choice.labelSize === Tokens.textSmall + 1, choice.radius);
            check("an icon-only choice is square", choiceIcon.implicitWidth === choiceIcon.implicitHeight, choiceIcon.implicitWidth + "x" + choiceIcon.implicitHeight);
            check("a slider takes no icon", sliderBare.icon === "" && sliderBare.wheel, sliderBare.icon);
            check("meter group", meter.group === "panels" && meterWidget.group === "widgets", meterWidget.group);
            check("chip height", chip.implicitHeight > Tokens.islandHeight, chip.implicitHeight);
            console.log(" DONE"); Qt.quit();
        }
    }
}
