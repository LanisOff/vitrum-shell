pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/alerts.js" as Lib

/*
 * Hardware alerts, as critical notifications (they show in a game and in Do
 * not disturb): a GPU or CPU that stays too hot, a disk that is nearly full,
 * a drive whose SMART says it is failing. The same alert at most once every
 * ten minutes (disks: once an hour, SMART: once a day).
 */
Singleton {
    id: root
    readonly property bool enabled: Settings.get("alerts.enabled", true)
    property var state: ({})
    function _t() { return Date.now() / 1000; }
    function _check(key, over, hold, cooldown) {
        const r = Lib.watch(state, key, over, _t(), hold, cooldown);
        state = r.state;
        return r.fire;
    }

    // Temperatures: SysInfo samples every 2 s while subscribed.
    Component.onCompleted: SysInfo.subscribe()
    Timer {
        interval: 5000; repeat: true; running: root.enabled
        onTriggered: {
            const g = Settings.get("alerts.gpu", 85), c = Settings.get("alerts.cpu", 90);
            if (SysInfo.gpuAvailable && root._check("gpu", SysInfo.gpuTemp >= g, 30, 600))
                Notifs.injectCritical("Hardware", "The GPU is at " + Math.round(SysInfo.gpuTemp) + " °C", "Over " + g + " °C for half a minute. Check the fans and the case airflow.");
            if (SysInfo.cpuTemp > 0 && root._check("cpu", SysInfo.cpuTemp >= c, 30, 600))
                Notifs.injectCritical("Hardware", "The CPU is at " + Math.round(SysInfo.cpuTemp) + " °C", "Over " + c + " °C for half a minute.");
        }
    }

    // Disks: every few minutes.
    Process {
        id: df
        command: ["df", "-P", "-B1", "-x", "tmpfs", "-x", "devtmpfs", "-x", "squashfs", "-x", "overlay", "-x", "efivarfs"]
        stdout: StdioCollector {
            onStreamFinished: {
                const full = Lib.fullDisks(text, Settings.get("alerts.diskPercent", 90), Settings.get("alerts.diskFreeGB", 10) * 1073741824);
                for (const d of full)
                    if (root._check("disk:" + d.mount, true, 0, 3600))
                        Notifs.injectCritical("Hardware", d.mount + " is nearly full", d.freeGB + " GB left (" + d.percent + "% used).");
            }
        }
    }
    Timer { interval: 300000; repeat: true; running: root.enabled; triggeredOnStart: true; onTriggered: if (!df.running) df.running = true }

    // SMART: a few minutes after login, then every six hours (through the root helper).
    readonly property string helper: "/usr/local/libexec/vitrum/vitrum-root"
    Process {
        id: smart
        command: ["sh", "-c", 'h="$1"; test -x "$h" && command -v smartctl >/dev/null || exit 0; for d in $(pkexec "$h" disks); do printf "%s\\t" "$d"; pkexec "$h" smart "$d" | tr -d "\\n"; echo; done', "_", root.helper]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0) continue;
                    let j = null;
                    try { j = JSON.parse(line.slice(tab + 1)); } catch (e) { continue; }
                    const why = Lib.smartProblem(j);
                    if (why && root._check("smart:" + line.slice(0, tab), true, 0, 86400))
                        Notifs.injectCritical("Hardware", "Drive " + line.slice(0, tab) + ": " + why, "Back up what is on it. (SMART, " + ((j.model_name || "") + "").trim() + ")");
                }
            }
        }
    }
    Timer { interval: 6 * 3600 * 1000; repeat: true; running: root.enabled && Settings.get("alerts.smart", true); onTriggered: if (!smart.running) smart.running = true }
    Timer { interval: 180000; running: root.enabled && Settings.get("alerts.smart", true); onTriggered: if (!smart.running) smart.running = true }
}
