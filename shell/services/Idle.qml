pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

/*
 * Idle: dim the screen (lock.dimMinutes), lock (lock.idleMinutes), turn the
 * monitors off (lock.screenOffMinutes) — 0 is never for each. All three wait
 * while something keeps the session awake (Awake: by hand, a fullscreen
 * video or game, or anything playing): its inhibitor is respected.
 *
 * Before sleep the screen locks (lock.beforeSleep) and sleep waits for it: a
 * delay inhibitor is held while awake and let go once the lock is up, so a
 * waking machine never shows the desktop. Also locks on `loginctl lock-session`.
 * The Lock module listens to lockRequested; IdleDim shows `dimmed`.
 */
Singleton {
    id: root
    signal lockRequested(string reason)
    /// The screen is dimmed for idleness (any input undims it).
    readonly property bool dimmed: dimMonitor.enabled && dimMonitor.isIdle

    // An idle watch of `minutes` (0: off). Quickshell keeps the timeout an
    // IdleMonitor started with, so a new one (settings load after start, or
    // change) re-arms it: off, then on again with the new timeout.
    component Watch: IdleMonitor {
        id: w
        property int minutes: 0
        timeout: Math.max(1, minutes) * 60
        respectInhibitors: true
        enabled: false
        onMinutesChanged: rearm()
        Component.onCompleted: rearm()
        function rearm() { enabled = false; Qt.callLater(() => w.enabled = w.minutes > 0); }
    }

    Watch { id: dimMonitor; minutes: Settings.get("lock.dimMinutes", 4) }
    Watch {
        minutes: Settings.get("lock.idleMinutes", 5)
        onIsIdleChanged: if (isIdle) root.lockRequested("idle")
    }
    Watch {
        minutes: Settings.get("lock.screenOffMinutes", 10)
        // niri turns them back on at the first key or motion.
        onIsIdleChanged: if (isIdle) Quickshell.execDetached(["niri", "msg", "action", "power-off-monitors"])
    }

    // ------------------------------------------------------ before sleep ---
    readonly property bool holdSleep: Settings.get("lock.beforeSleep", true)
    property bool sleeping: false
    property bool letGo: false
    // logind or elogind: sleep is delayed (up to its InhibitDelayMaxSec) while this runs.
    // It holds on by reading the shell's end of stdin, not `sleep infinity`: a
    // shell that is killed (a restart, an update, a crash) never stops its
    // children, and one left behind went on delaying every sleep. The pipe
    // closes with the shell, whatever ends it.
    Process {
        id: inhibitor
        running: root.holdSleep && !root.letGo
        stdinEnabled: true
        command: ["sh", "-c", "i=$(command -v elogind-inhibit || command -v systemd-inhibit) || exit 0; " +
                  "exec \"$i\" --what=sleep --mode=delay --who=vitrum --why='Locking the screen first' cat"]
    }
    /// The lock is up on every screen: sleep may go on.
    function lockShown() { if (sleeping) release.restart(); }
    // A frame for the lock to be drawn; and never hold sleep for long.
    Timer { id: release; interval: 250; onTriggered: root.letGo = true }
    Timer { id: giveUp; interval: 3000; onTriggered: root.letGo = true }

    // logind and elogind both speak org.freedesktop.login1 on the system bus.
    // Without either (Void with seatd only) gdbus monitor gives up at once, and
    // started again every few seconds it would do so for ever: so first ask
    // the bus whether the name is there, and if not, ask again in a minute
    // (elogind may be started later). The monitor runs only once it is.
    Process {
        id: probe
        running: true
        command: ["sh", "-c", "gdbus call --system --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus "
                  + "--method org.freedesktop.DBus.NameHasOwner org.freedesktop.login1 2>/dev/null | grep -q true && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "yes") monitor.running = true;
                else { retry.interval = 60000; retry.restart(); }
            }
        }
    }
    // gdbus writes only when login1 speaks, so after a killed shell it would
    // wait for ever: it is stopped once stdin closes (the background job gets
    // stdin on fd 3, since sh gives background jobs /dev/null).
    Process {
        id: monitor
        stdinEnabled: true
        command: ["sh", "-c", "exec 3<&0; gdbus monitor --system --dest org.freedesktop.login1 & g=$!; "
                  + "{ cat >/dev/null <&3; kill $g 2>/dev/null; } & wait $g"]
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("PrepareForSleep (true") >= 0) {
                    root.sleeping = true;
                    if (root.holdSleep) { root.lockRequested("sleep"); giveUp.restart(); }
                } else if (line.indexOf("PrepareForSleep (false") >= 0) {
                    root.sleeping = false;
                    release.stop(); giveUp.stop();
                    root.letGo = false;
                } else if (line.indexOf(".Session.Lock ()") >= 0) root.lockRequested("loginctl");
            }
        }
        onExited: { retry.interval = 5000; retry.restart(); }
    }
    Timer { id: retry; interval: 5000; onTriggered: probe.running = true }
}
