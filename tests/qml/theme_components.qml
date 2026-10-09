import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components

ShellRoot {
    id: root
    function check(name, ok, why) { console.log((ok ? " PASS " : " FAIL ") + name + (ok ? "" : ": " + why)); }
    Component.onCompleted: Settings.ready

    // Instantiate every component off-screen.
    Item {
        id: host
        Island { id: island; Label { text: "12:34"; numeric: true } Icon { name: "wifi" } }
        Capsule { id: cap; icon: "lock"; label: "Lock" }
        Chip { id: chip; icon: "bluetooth"; title: "Bluetooth"; subtitle: "Off"; hasMenu: true }
        Slider { id: slider; value: 0.4 }
        Toggle { id: toggle; checked: true }
        Card { id: card; Label { text: "x" } }
        Surface { id: glassy; group: "launcher" }
        Surface { id: solidy; group: "bar" }
    }

    Timer {
        interval: 2500; running: true
        onTriggered: {
            check("density comfortable → island 38", Tokens.islandHeight === 38, Tokens.islandHeight);
            check("radius is half the island", Tokens.islandRadius === 19, Tokens.islandRadius);
            check("scheme forced light", Colors.scheme === "light" && !Colors.dark, Colors.scheme);
            check("fallback palette (no palette.json) is graphite light", Colors.surface.toString() === "#ffffff", Colors.surface);
            check("glass group fill is translucent", glassy.color.a < 0.3, glassy.color.a);
            check("solid group fill is opaque", solidy.color.a === 1, solidy.color.a);
            check("island sizes to content", island.implicitWidth > 2 * Tokens.padding + 20, island.implicitWidth);
            check("icons map loaded", Icons.glyph("wifi").text === "wifi", JSON.stringify(Icons.glyph("wifi")));
            check("mono preset falls back for missing nerd glyph", Icons.glyph("network-off").font === "material", "");
            check("springs scale with speed", Motion.smooth.spring === 6, Motion.smooth.spring);
            check("chip height", chip.implicitHeight > Tokens.islandHeight, chip.implicitHeight);
            console.log(" DONE"); Qt.quit();
        }
    }
}
