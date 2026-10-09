import QtQuick
import Quickshell
import qs.services
// settings.json has a wrong type (density), a bad enum (bar.position) and a good value.
ShellRoot {
    function check(name, ok, why) { console.log((ok ? " PASS " : " FAIL ") + name + (ok ? "" : ": " + why)); }
    Connections {
        target: Settings
        function onReadyChanged() {
            if (!Settings.ready) return;
            check("wrong type falls back", Settings.get("density") === "compact", Settings.get("density"));
            check("good value applies", Settings.get("materials.default") === "glass", Settings.get("materials.default"));
            check("bad enum falls back", Settings.get("bar.position") === "top", Settings.get("bar.position"));
            check("defaults fill the rest", Settings.get("dock.iconSize") === 44, Settings.get("dock.iconSize"));
            check("two warnings", Settings.warnings.length === 2, JSON.stringify(Settings.warnings));
            console.log(" DONE"); Qt.quit();
        }
    }
    Timer { interval: 8000; running: true; onTriggered: { console.log(" FAIL timeout: never ready"); console.log(" DONE"); Qt.quit(); } }
}
