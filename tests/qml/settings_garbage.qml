import QtQuick
import Quickshell
import qs.services
// settings.json is not JSON: the shell keeps defaults and reports the error.
ShellRoot {
    Component.onCompleted: Settings.ready   // singletons are created on first use
    function check(name, ok, why) { console.log((ok ? " PASS " : " FAIL ") + name + (ok ? "" : ": " + why)); }
    Timer {
        interval: 2500; running: true
        onTriggered: {
            check("error reported", Settings.error.indexOf("not valid JSON") >= 0, Settings.error);
            check("defaults still usable", Settings.get("density", "x") === "compact", Settings.get("density", "x"));
            console.log(" DONE"); Qt.quit();
        }
    }
}
