import QtQuick
import Quickshell
import qs.components

// A window built on demand (components/OnDemand.qml) with the MapGate it keeps
// its `open` behind: built when wanted, its `open` changes after it exists,
// kept for `keep` after the last time it was wanted, then gone.
ShellRoot {
    id: root
    function check(name, ok, why) { console.log((ok ? " PASS " : " FAIL ") + name + (ok ? "" : ": " + why)); }

    property bool on: false
    property int opened: 0
    property var seenAtBuild: null

    OnDemand {
        id: lazy
        want: root.on
        keep: 400
        Scope {
            id: win
            readonly property bool open: gate.ready && root.on
            readonly property alias gate_: gate
            property int stamp: 0
            MapGate { id: gate; want: win.open; linger: 1 }
            onOpenChanged: if (open) root.opened++
            Component.onCompleted: root.seenAtBuild = win.open
        }
    }

    property int step: 0
    property var first: null
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            root.step++;
            switch (root.step) {
            case 1:
                check("nothing is built before it is wanted", lazy.item === null, lazy.item);
                root.on = true;
                check("built the moment it is wanted", lazy.item !== null, lazy.item);
                check("closed while it is being built", root.seenAtBuild === false, root.seenAtBuild);
                root.first = lazy.item;
                root.first.stamp = 7;
                break;
            case 2:
                check("open goes true after it exists", lazy.item.open === true, lazy.item.open);
                check("onOpenChanged ran once", root.opened === 1, root.opened);
                check("mapped once open", lazy.item.gate_.mapped === true, lazy.item.gate_.mapped);
                root.on = false;
                check("not thrown away at once", lazy.item !== null, lazy.item);
                break;
            case 3:
                check("closes while kept", lazy.item.open === false, lazy.item.open);
                root.on = true;                 // back within `keep`
                break;
            case 4:
                check("the same object when wanted again", lazy.item === root.first && lazy.item.stamp === 7, lazy.item);
                check("onOpenChanged ran again", root.opened === 2, root.opened);
                root.on = false;
                break;
            case 10:                            // past `keep`
                check("gone after keep", lazy.item === null, lazy.item);
                root.on = true;
                check("built anew", lazy.item !== null && lazy.item.stamp === 0, lazy.item);
                break;
            case 11:
                check("a new window opens too", lazy.item.open === true && root.opened === 3, root.opened);
                console.log(" DONE"); Qt.quit();
                break;
            }
        }
    }
}
