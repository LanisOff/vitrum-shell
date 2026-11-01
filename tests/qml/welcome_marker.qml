import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.welcome

// The installer's marker opens the tour at shell start, whatever window is or
// is not built by then, and closing the tour takes the marker away.
ShellRoot {
    id: root
    function check(name, ok, why) { console.log((ok ? " PASS " : " FAIL ") + name + (ok ? "" : ": " + why)); }
    readonly property string file: Quickshell.env("XDG_DATA_HOME") + "/vitrum/welcome"

    WelcomeMarker {}

    property int step: 0
    Timer {
        interval: 300; running: true; repeat: true
        onTriggered: {
            root.step++;
            if (root.step === 2) {
                check("the marker opens the tour", UiState.welcome === true, UiState.welcome);
                UiState.welcome = false;
            } else if (root.step === 4) {
                gone.running = true;
            }
        }
    }
    Process {
        id: gone
        command: ["test", "-e", root.file]
        onExited: code => {
            check("closing it takes the marker away", code !== 0, code);
            console.log(" DONE"); Qt.quit();
        }
    }
}
