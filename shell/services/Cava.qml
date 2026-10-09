pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * A spectrum of what plays, from cava (raw output), for the player's visualizer.
 * Runs only while something shows it and music plays.
 */
Singleton {
    id: root
    property int barCount: 32
    property var bars: []              // 0..1, barCount of them
    property int users: 0
    function subscribe() { users++; }
    function unsubscribe() { users = Math.max(0, users - 1); }
    readonly property bool active: users > 0 && Media.playing

    readonly property string config: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/vitrum-cava.conf"
    Process {
        running: root.active
        command: ["sh", "-c", 'command -v cava >/dev/null || exit 0; printf "%s" "$2" > "$1"; exec cava -p "$1"', "_", root.config,
                  "[general]\nbars = " + root.barCount + "\nframerate = 30\nautosens = 1\n[input]\nmethod = pipewire\nsource = auto\n" +
                  "[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\nbar_delimiter = 59\nframe_delimiter = 10\n"]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";").filter(x => x.length).map(x => Math.min(1, (+x || 0) / 100));
                if (v.length) root.bars = v;
            }
        }
        onRunningChanged: if (!running) root.bars = []
    }
}
