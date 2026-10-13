import QtQuick
import Quickshell
import qs.components

// Sparkline: points for every value, scaled to the peak (or the given max).
ShellRoot {
    FloatingWindow {
        visible: false
        Sparkline { id: a; width: 100; height: 40; values: [0, 1, 2, 4] }
        Sparkline { id: b; width: 100; height: 40; values: [0, 0, 0] }
        Sparkline { id: c; width: 100; height: 40; values: [1, 2]; max: 4 }
    }
    function check(name, ok, why) { console.log((ok ? "PASS " : "FAIL ") + name + (ok ? "" : ": " + why)); }
    Timer {
        interval: 300; running: true
        onTriggered: {
            check("points per value", a.pts.length === 4, "got " + a.pts.length);
            check("peak is the largest", a.peak === 4, "got " + a.peak);
            check("the peak sits at the top", Math.abs(a.pts[3].y - a.lineWidth) < 0.01, "y " + a.pts[3].y);
            check("zero sits at the bottom", Math.abs(a.pts[0].y - (40 - a.lineWidth)) < 0.01, "y " + a.pts[0].y);
            check("all zeros still draw", b.pts.length === 3, "got " + b.pts.length);
            check("a given max scales", Math.abs(c.pts[1].y - (40 - c.lineWidth - 0.5 * (40 - 2 * c.lineWidth))) < 0.01, "y " + c.pts[1].y);
            console.log("DONE");
            Qt.quit();
        }
    }
}
