import QtQuick
import Quickshell
import qs.components

// What moves in a glass body has to ask for a frame. Since Qt 6.12 a change
// inside an invisible item does not, so the body must stay effectively visible
// and be hidden as a source instead: the clock's digits stood half way through
// their roll until something else on the window drew.
ShellRoot {
    FloatingWindow {
        visible: false
        Glass {
            width: 100; height: 40
            Rectangle { id: body; anchors.fill: parent }
        }
    }
    function check(name, ok, why) { console.log((ok ? "PASS " : "FAIL ") + name + (ok ? "" : ": " + why)); }
    Timer {
        interval: 300; running: true
        onTriggered: {
            check("the body is effectively visible", body.visible, "body.visible is false");
            console.log("DONE");
            Qt.quit();
        }
    }
}
