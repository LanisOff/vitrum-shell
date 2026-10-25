import QtQuick
import Quickshell
import qs.components
import qs.theme

// Meters move only for a real step (Motion.meterStep) and only while shown: a
// live figure's small changes are set at once, since every animation that
// starts wakes all the shell's windows for a frame.
ShellRoot {
    FloatingWindow {
        visible: false
        Ring { id: ring; width: 64; height: 64; value: 0.5 }
        Ring { id: hidden; visible: false; width: 64; height: 64; value: 0.5 }
        Meter { id: bar; kind: "linear"; width: 160; value: 0.5 }
    }
    function check(name, ok, why) { console.log((ok ? "PASS " : "FAIL ") + name + (ok ? "" : ": " + why)); }
    Timer {
        interval: 300; running: true
        onTriggered: {
            check("motion is on here", Motion.enabled, "Motion.enabled is false");
            ring.value = 0.52; bar.value = 0.52;
            check("a small step is set at once", Math.abs(ring.shown - 0.52) < 1e-6, "shown " + ring.shown);
            ring.value = 0.95; bar.value = 0.95; hidden.value = 0.95;
            check("a real step moves", ring.shown < 0.95, "shown " + ring.shown);
            check("a hidden ring does not move", Math.abs(hidden.shown - 0.95) < 1e-6, "shown " + hidden.shown);
            settle.start();
        }
    }
    Timer {
        id: settle
        interval: 2500
        onTriggered: {
            check("a real step arrives", Math.abs(ring.shown - 0.95) < 0.01, "shown " + ring.shown);
            console.log("DONE");
            Qt.quit();
        }
    }
}
