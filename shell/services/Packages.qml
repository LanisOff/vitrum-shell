pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/emerge.js" as Emerge
import "../lib/pacman.js" as Pacman
import "../lib/xbps.js" as Xbps
import "../lib/dnf.js" as Dnf

/*
 * The package manager, seen from the bar — Portage on Gentoo, pacman on Arch,
 * xbps on Void, dnf on Fedora (whichever the system has):
 *
 *   the run going on now   Portage: /var/log/emerge.log (readable for the
 *                          portage group, which the installer adds you to);
 *                          pacman: /var/log/pacman.log, while its database
 *                          lock is held. xbps and dnf: only the run our
 *                          Update button started, with no steps (xbps keeps
 *                          no log, and dnf's is for debugging), followed
 *                          through the file it writes (rcFile: "started
 *                          PID", then its exit code). Told when it ends.
 *   the updates waiting    Portage: emerge -puDN @world after each sync;
 *                          pacman: checkupdates (or pacman -Qu); xbps:
 *                          xbps-install -Mun; dnf: dnf check-update. All
 *                          without root, in the background, at most every few
 *                          hours.
 *
 * All read into the same shape (lib/emerge.js, pacman.js, xbps.js, dnf.js).
 */
Singleton {
    id: root
    /// "portage" | "pacman" | "xbps" | "dnf" | "" (none of them)
    property string backend: ""
    readonly property bool gentoo: backend === "portage"
    /// No log to follow (xbps, dnf): a run is only running, then over.
    readonly property bool logless: backend === "xbps" || backend === "dnf"
    readonly property string toolName: backend === "portage" ? "emerge" : backend
    readonly property string who: ({ portage: "Portage", pacman: "pacman", xbps: "xbps", dnf: "dnf" })[backend] || ""
    // Where our update command says it runs, then how it ended (the logless backends).
    readonly property string rcFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/vitrum-update." + backend + ".rc"
    property var state: ({ running: false, ok: true, done: 0, total: 0, current: "", since: 0, started: 0, failed: "" })
    property real now: Date.now() / 1000
    readonly property int secondsLeft: Emerge.eta(state, now)
    property bool readable: true

    Process {
        running: true
        command: ["sh", "-c", "if command -v emerge >/dev/null; then echo portage; elif command -v pacman >/dev/null; then echo pacman; "
                  + "elif command -v xbps-install >/dev/null; then echo xbps; elif command -v dnf >/dev/null; then echo dnf; fi"]
        stdout: StdioCollector { onStreamFinished: root.backend = text.trim() }
    }

    // A run ended: say how.
    property bool wasRunning: false
    onStateChanged: {
        if (wasRunning && !state.running) {
            if (state.ok) Notifs.inject(who, gentoo ? "Emerge finished" : "Update finished",
                                        state.total ? state.total + " packages built" : state.done ? state.done + " packages" : "");
            else Notifs.inject(who, state.interrupted ? "Update interrupted" : gentoo ? "Emerge failed" : "Update failed",
                               state.failed ? state.failed + (gentoo ? " did not build" : " did not install")
                               : state.interrupted ? "Its window closed before it finished."
                               : logFile ? "See " + logFile : "See its terminal window");
            built();
            updatesLater.restart();
        }
        wasRunning = state.running;
    }
    signal built()
    readonly property string logFile: gentoo ? "/var/log/emerge.log" : backend === "pacman" ? "/var/log/pacman.log" : ""

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
    // xbps and dnf: the file our update command writes, and whether the shell
    // it names still runs. Not any run of root's: dnf makecache on a timer, or
    // dnf5 automatic, is not an update you asked for (and could otherwise set
    // off a power off planned for after it).
    Process {
        id: watch
        // An empty file is one being written (the code replacing "started"):
        // read again at the next poll rather than take it for a cut-off run.
        command: ["sh", "-c", '[ -f "$1" ] || exit 0; read -r mark pid < "$1"; [ -n "$mark" ] || { echo busy; exit 0; }; '
                  + 'if [ "$mark" = started ] && kill -0 "$pid" 2>/dev/null; then echo "$mark ALIVE"; else echo "$mark GONE"; fi', "_", root.rcFile]
        stdout: StdioCollector {
            onStreamFinished: {
                const w = text.trim().split(/\s+/);
                if (w[0] === "busy") return;
                const s = Xbps.runState(root.state, w.length > 1 ? w[0] : "", w[1] === "ALIVE", root.now);
                root.readable = true;
                if (JSON.stringify(s) !== JSON.stringify(root.state)) root.state = s;
            }
        }
    }
    // Fast while something runs, slow otherwise, slower still in a game (a
    // shutdown after the build still comes, a minute late at most).
    Timer {
        interval: GameMode.active ? 60000 : root.state.running ? 2000 : 15000; repeat: true; running: root.backend !== ""; triggeredOnStart: true
        onTriggered: {
            root.now = Date.now() / 1000;
            const p = root.logless ? watch : tail;
            if (!p.running) p.running = true;
        }
    }

    // ---------------------------------------------------------- updates ---
    property var updates: []          // [{ atom, from, to, kind }]
    property real checkedSync: 0
    property bool checking: false
    Timer { id: updatesLater; interval: 5000; onTriggered: root.checkUpdates(true) }
    Timer { interval: 3 * 3600 * 1000; repeat: true; running: root.backend !== ""; triggeredOnStart: true; onTriggered: root.checkUpdates(false) }
    function checkUpdates(force) {
        if (checking || state.running || !backend) return;
        if (backend === "pacman") { checking = true; pacmanCheck.running = true; return; }
        if (logless) { checking = true; loglessCheck.running = true; return; }
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
    // xbps-install -M syncs the repositories into memory only, so it needs no
    // root and leaves root's cache alone; it exits 0 even when no repository
    // could be opened, and only says so on stderr (hence 2>&1, and
    // Xbps.checkFailed). dnf check-update keeps a cache of your own and
    // refreshes it when the repositories' metadata expires (not --refresh:
    // that would fetch Fedora's whole metadata every few hours); it exits 100
    // with updates, 0 without, 1 when it could not check. A check that could
    // not be made keeps the list there was. After a marker, the installed
    // versions, for "from".
    Process {
        id: loglessCheck
        command: ["sh", "-c", 'if [ "$1" = xbps ]; then nice -n 19 xbps-install -Mun 2>&1; echo "@@rc 0"; echo "@@installed"; xbps-query -l 2>/dev/null; '
                  + 'else nice -n 19 dnf check-update -q 2>/dev/null; echo "@@rc $?"; echo "@@installed"; '
                  + "rpm -qa --qf '%{NAME}.%{ARCH} %|EPOCH?{%{EPOCH}:}:{}|%{VERSION}-%{RELEASE}\\n' 2>/dev/null; fi", "_", root.backend]
        stdout: StdioCollector {
            onStreamFinished: {
                // A check with nothing to say starts with the marker itself.
                const t = "\n" + text, i = t.indexOf("\n@@rc "), k = t.indexOf("\n@@installed\n");
                const out = i >= 0 ? t.slice(1, i) : t, rc = i >= 0 ? parseInt(t.slice(i + 6), 10) : -1;
                const installed = k >= 0 ? t.slice(k + 13) : "";
                if (root.backend === "xbps" && !Xbps.checkFailed(out)) root.updates = Xbps.parseUpdates(out, installed);
                else if (root.backend === "dnf" && (rc === 0 || rc === 100)) root.updates = rc === 0 ? [] : Dnf.parseUpdates(out, installed);
                root.checking = false;
            }
        }
        onExited: checking = false
    }
    /// Update everything, in a terminal (it asks before doing anything).
    function update() {
        const cmds = {
            portage: "sudo emerge --ask --verbose --update --deep --newuse @world",
            pacman: "if command -v paru >/dev/null; then paru -Syu; elif command -v yay >/dev/null; then yay -Syu; else sudo pacman -Syu; fi",
            // That it runs (this shell's PID), then its exit code: no log says either.
            xbps: 'echo "started $$" > "$1"; sudo xbps-install -Su; echo $? > "$1"',
            dnf: 'echo "started $$" > "$1"; sudo dnf upgrade; echo $? > "$1"'
        };
        const titles = { portage: "Updating Gentoo", pacman: "Updating Arch", xbps: "Updating Void", dnf: "Updating Fedora" };
        if (!cmds[backend]) return;
        Quickshell.execDetached(["kitty", "--title", titles[backend], "-e", "sh", "-c",
                                 cmds[backend] + "; echo; echo 'Press Enter to close.'; read -r _", "_", rcFile]);
    }
}
