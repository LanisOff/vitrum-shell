pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * How far the vitrum checkout is behind its repository (vitrum behind --json):
 * a quiet check two minutes after the shell starts and every few hours, never
 * pulling anything. The bar's update island shows once it is `threshold`
 * commits behind (updates.vitrum.threshold); its panel lists them and runs
 * vitrum update in a terminal.
 */
Singleton {
    id: root
    readonly property bool enabled: Settings.get("updates.vitrum.check", true)
    readonly property int threshold: Math.max(1, Settings.get("updates.vitrum.threshold", 3))
    readonly property real hours: Math.max(1, Settings.get("updates.vitrum.hours", 6))

    property int behind: 0
    property var commits: []
    property string error: ""
    property string url: ""
    property bool checking: false
    property date checkedAt: new Date(0)
    readonly property bool due: enabled && behind >= threshold

    function check() {
        if (checking) return;
        checking = true;
        proc.running = true;
    }
    function update() {
        Quickshell.execDetached(["kitty", "--title", "Updating vitrum", "-e", "sh", "-c",
                                 "vitrum update; echo; echo 'Press Enter to close.'; read -r _"]);
    }

    Process {
        id: proc
        command: ["vitrum", "behind", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const v = JSON.parse(text);
                    root.behind = Number(v.behind) || 0;
                    root.commits = Array.isArray(v.commits) ? v.commits : [];
                    root.error = v.error || "";
                    root.url = v.url || "";
                } catch (e) {
                    root.error = "vitrum behind gave no answer";
                }
                root.checkedAt = new Date();
                root.checking = false;
            }
        }
        onExited: code => { if (code !== 0) { root.checking = false; if (!root.error) root.error = "vitrum behind failed"; } }
    }
    Timer { running: root.enabled; interval: 2 * 60 * 1000; onTriggered: root.check() }
    Timer { running: root.enabled; interval: root.hours * 3600 * 1000; repeat: true; onTriggered: root.check() }
}
