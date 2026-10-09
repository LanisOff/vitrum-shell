pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/emerge.js" as Emerge
import "../lib/pacman.js" as Pacman

/*
 * The package manager, seen from the bar — Portage on Gentoo, pacman on Arch
 * (whichever the system has):
 *
 *   the run going on now   Portage: /var/log/emerge.log (readable for the
 *                          portage group, which the installer adds you to);
 *                          pacman: /var/log/pacman.log, while its database
 *                          lock is held. Told when it ends.
 *   the updates waiting    Portage: emerge -puDN @world after each sync;
 *                          pacman: checkupdates (or pacman -Qu). In the
 *                          background, at most every few hours.
 *
 * Both read into the same shape (lib/emerge.js, lib/pacman.js).
 */
Singleton {
    id: root
    /// "portage" | "pacman" | "" (neither)
    property string backend: ""
    readonly property bool gentoo: backend === "portage"
    readonly property string toolName: backend === "pacman" ? "pacman" : "emerge"
    property var state: ({ running: false, ok: true, done: 0, total: 0, current: "", since: 0, started: 0, failed: "" })
    property real now: Date.now() / 1000
    readonly property int secondsLeft: Emerge.eta(state, now)
    property bool readable: true

    Process {
        running: true
        command: ["sh", "-c", "command -v emerge >/dev/null && echo portage || { command -v pacman >/dev/null && echo pacman; } || true"]
        stdout: StdioCollector { onStreamFinished: root.backend = text.trim() }
    }

    // A run ended: say how.
    property bool wasRunning: false
    onStateChanged: {
        if (wasRunning && !state.running) {
            const who = gentoo ? "Portage" : "pacman";
            if (state.ok) Notifs.inject(who, gentoo ? "Emerge finished" : "Update finished",
                                        state.total ? state.total + " packages built" : state.done ? state.done + " packages" : "");
            else Notifs.inject(who, gentoo ? "Emerge failed" : "Update failed",
                               state.failed ? state.failed + (gentoo ? " did not build" : " did not install") : "See " + logFile);
            built();
            updatesLater.restart();
        }
        wasRunning = state.running;
    }
    signal built()
    readonly property string logFile: gentoo ? "/var/log/emerge.log" : "/var/log/pacman.log"

    Process {
        id: tail
        // A run killed without its last lines (power loss) would read as running
        // forever: the first line says whether the tool is there at all (emerge
        // running; pacman's database lock held).
        command: root.gentoo
            ? ["sh", "-c", 'f=/var/log/emerge.log; [ -r "$f" ] || { echo NOACCESS; exit 0; }; pgrep -x emerge >/dev/null && echo ALIVE || echo GONE; tail -n 600 "$f"']
            : ["sh", "-c", 'f=/var/log/pacman.log; [ -r "$f" ] || { echo NOACCESS; exit 0; }; [ -e /var/lib/pacman/db.lck ] && echo ALIVE || echo GONE; tail -n 400 "$f"']
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "NOACCESS") { root.readable = false; return; }
                root.readable = true;
                const nl = text.indexOf("\n");
                const alive = text.slice(0, nl) === "ALIVE";
                const s = root.gentoo ? Emerge.parseLog(text.slice(nl + 1)) : Pacman.parseLog(text.slice(nl + 1));
                if (!alive && s.running) s.running = false;
                if (!root.gentoo) {
                    // Syncing and downloading come before the log says anything.
                    if (alive && !s.running) Object.assign(s, { running: true, ok: true, done: 0, current: "", started: root.now, since: root.now, failed: "" });
                    // pacman logs no count: the updates it was asked for are the total.
                    s.total = s.running && root.updates.length > s.done ? root.updates.length : 0;
                }
                if (JSON.stringify(s) !== JSON.stringify(root.state)) root.state = s;
            }
        }
    }
    // Fast while something runs, slow otherwise.
    Timer {
        interval: root.state.running ? 2000 : 15000; repeat: true; running: root.backend !== ""; triggeredOnStart: true
        onTriggered: { root.now = Date.now() / 1000; if (!tail.running) tail.running = true; }
    }

    // ---------------------------------------------------------- updates ---
    property var updates: []          // [{ atom, from, to, kind }]
    property real checkedSync: 0
    property bool checking: false
    Timer { id: updatesLater; interval: 5000; onTriggered: root.checkUpdates(true) }
    Timer { interval: 3 * 3600 * 1000; repeat: true; running: root.backend !== ""; triggeredOnStart: true; onTriggered: root.checkUpdates(false) }
    function checkUpdates(force) {
        if (checking || state.running || !backend) return;
        if (!gentoo) { checking = true; pacmanCheck.running = true; return; }
        syncStamp.force = force;
        syncStamp.running = true;
    }
    Process {
        id: syncStamp
        property bool force: false
        command: ["sh", "-c", 'stat -c %Y /var/db/repos/gentoo/metadata/timestamp.chk 2>/dev/null || stat -c %Y /var/db/repos/gentoo 2>/dev/null || echo 0']
        stdout: StdioCollector {
            onStreamFinished: {
                const t = parseFloat(text) || 0;
                if (!syncStamp.force && t > 0 && t === root.checkedSync) return;
                root.checkedSync = t;
                root.checking = true;
                pretend.running = true;
            }
        }
    }
    Process {
        id: pretend
        command: ["sh", "-c", 'command -v emerge >/dev/null || exit 0; nice -n 19 emerge -puDN --color=n --nospinner @world 2>/dev/null']
        stdout: StdioCollector { onStreamFinished: { root.updates = Emerge.parseUpdates(text); root.checking = false; } }
        onExited: checking = false
    }
    // checkupdates syncs a copy of the databases, so it needs no root.
    Process {
        id: pacmanCheck
        command: ["sh", "-c", 'if command -v checkupdates >/dev/null; then nice -n 19 checkupdates 2>/dev/null; else pacman -Qu 2>/dev/null; fi; true']
        stdout: StdioCollector { onStreamFinished: { root.updates = Pacman.parseUpdates(text); root.checking = false; } }
        onExited: checking = false
    }
    /// Update everything, in a terminal (it asks before doing anything).
    function update() {
        const cmd = gentoo ? "sudo emerge --ask --verbose --update --deep --newuse @world"
                  : "if command -v paru >/dev/null; then paru -Syu; elif command -v yay >/dev/null; then yay -Syu; else sudo pacman -Syu; fi";
        Quickshell.execDetached(["kitty", "--title", gentoo ? "Updating Gentoo" : "Updating Arch", "-e", "sh", "-c",
                                 cmd + "; echo; echo 'Press Enter to close.'; read -r _"]);
    }
}
