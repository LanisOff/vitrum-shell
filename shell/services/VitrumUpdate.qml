pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/vitrumupdate.js" as Lib

/*
 * How far the install is behind the vitrum repository (vitrum behind --json):
 * a quiet check two minutes after the shell starts and every few hours, never
 * pulling anything, and once more when an install finishes. The bar's update
 * island shows once it is `threshold` commits behind
 * (updates.vitrum.threshold) or a major version is out (lib/vitrumupdate.js);
 * its panel lists the commits, however few, and runs vitrum update in a
 * terminal.
 */
Singleton {
    id: root
    readonly property bool enabled: Settings.get("updates.vitrum.check", true)
    readonly property int threshold: Math.max(1, Settings.get("updates.vitrum.threshold", 5))
    readonly property real hours: Math.max(1, Settings.get("updates.vitrum.hours", 6))

    property int behind: 0
    property var commits: []
    property string error: ""
    property string url: ""
    property string installed: ""
    property string remote: ""
    property bool checking: false
    property date checkedAt: new Date(0)
    readonly property var notice: Lib.decide(behind, threshold, installed, remote)
    readonly property bool due: enabled && notice.due
    readonly property string badge: Lib.badge(notice, behind)
    readonly property string title: Lib.title(notice, behind)

    function check() {
        if (checking) return;
        checking = true;
        proc.running = true;
    }
    // In a terminal, so the installer can show its choice screen when the
    // update brings something new; without one it would take the defaults.
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
                    root.installed = v.installed || "";
                    root.remote = v.remote || "";
                } catch (e) {
                    root.error = "vitrum behind gave no answer";
                }
                root.checkedAt = new Date();
                root.checking = false;
            }
        }
        onExited: code => { if (code !== 0) { root.checking = false; if (!root.error) root.error = "vitrum behind failed"; } }
    }
    // The installer records every run here, from the panel or by hand: look
    // again, so the island leaves without waiting for the next check. It only
    // restarts the shell when the shell stage ran and the screen is unlocked.
    FileView {
        path: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/vitrum/install.json"
        watchChanges: true
        printErrors: false
        onFileChanged: { reload(); if (root.enabled) root.check(); }
    }
    Timer { running: root.enabled; interval: 2 * 60 * 1000; onTriggered: root.check() }
    Timer { running: root.enabled; interval: root.hours * 3600 * 1000; repeat: true; onTriggered: root.check() }
}
