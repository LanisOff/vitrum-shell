pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/calendar.js" as Lib

/*
 * Calendar events (tools/vitrum-calendar: local always, CalDAV or Google when
 * connected, synced every quarter of an hour). The panel asks for the weeks it
 * shows; today's events are kept apart for the reminders, ten minutes before
 * (calendar.remindMinutes).
 */
Singleton {
    id: root
    // The Settings app loads this too (VITRUM_NO_THEME): it only configures;
    // reminders and syncing are the shell's.
    readonly property bool inShell: !Quickshell.env("VITRUM_NO_THEME")
    property var events: []           // the window the panel shows
    property date from: new Date()
    property int days: 42
    property var today: []
    property var status: ({ connected: false, kind: "", calendars: ["local"] })
    property var reminded: ({})
    /// What the last connect attempt came to (shown in Settings).
    property string connectResult: ""

    function show(start, n) { from = start; days = n; _load(); }
    function _load() { list.command = ["vitrum-calendar", "list", Lib.ymd(from), String(days)]; if (!list.running) list.running = true; else again = true; }
    property bool again: false
    Process {
        id: list
        stdout: StdioCollector { onStreamFinished: { try { root.events = JSON.parse(text); } catch (e) { root.events = []; } } }
        onExited: if (root.again) { root.again = false; running = true; }
    }

    function add(title, day, time, minutes) {
        const cmd = ["vitrum-calendar", "add", title, Lib.ymd(day)].concat(time ? [time, String(minutes || 60)] : []);
        changer.command = cmd; changer.running = true;
    }
    function remove(uid) { changer.command = ["vitrum-calendar", "delete", uid]; changer.running = true; }
    Process {
        id: changer
        stderr: StdioCollector { onStreamFinished: if (text.trim() && root.inShell) Notifs.inject("Calendar", "Could not change the calendar", text.trim()) }
        onExited: { root._load(); root._loadToday(); }
    }

    // Today, for the reminders.
    function _loadToday() {
        if (todayProc.running) return;
        todayProc.command = ["vitrum-calendar", "list", Lib.ymd(new Date()), "1"];   // today, as of now
        todayProc.running = true;
    }
    Process {
        id: todayProc
        stdout: StdioCollector { onStreamFinished: { try { root.today = JSON.parse(text); } catch (e) { root.today = []; } } }
    }
    Timer { interval: 600000; repeat: true; running: root.inShell; triggeredOnStart: true; onTriggered: root._loadToday() }
    Timer {
        interval: 30000; repeat: true; running: root.inShell && root.today.length > 0
        onTriggered: {
            const now = new Date(), mins = Settings.get("calendar.remindMinutes", 10);
            for (const e of root.today) {
                const key = e.uid + e.start;
                if (!root.reminded[key] && Lib.due(e, now, mins)) {
                    const r = Object.assign({}, root.reminded); r[key] = true; root.reminded = r;
                    Notifs.inject("Calendar", e.title, "At " + Lib.timeOf(e) + (e.location ? " · " + e.location : ""));
                }
            }
        }
    }

    // Connected calendars: status, and a sync every quarter of an hour.
    function refreshStatus() { if (!statusProc.running) statusProc.running = true; }
    Process {
        id: statusProc
        command: ["vitrum-calendar", "status"]
        stdout: StdioCollector { onStreamFinished: { try { root.status = JSON.parse(text); } catch (e) {} } }
    }
    Component.onCompleted: refreshStatus()
    Timer { interval: 900000; repeat: true; running: root.inShell && root.status.connected; onTriggered: if (!syncProc.running) syncProc.running = true }
    Process { id: syncProc; command: ["vitrum-calendar", "sync"]; onExited: { root._load(); root._loadToday(); } }
    function syncNow() { if (!syncProc.running) syncProc.running = true; }

    /// Connect a CalDAV server. The password is written to the helper's stdin,
    /// never put on a command line (where any process could read it).
    property string _pending: ""
    function connect(url, user, password) {
        _pending = password;
        connectProc.command = ["vitrum-calendar", "connect", url, user];
        connectProc.running = true;
    }
    Process {
        id: connectProc
        stdinEnabled: true
        onStarted: { write(root._pending + "\n"); root._pending = ""; stdinEnabled = false; }
        stderr: StdioCollector { id: connectErr }
        onExited: code => {
            root.connectResult = code === 0 ? "Connected. Events sync every 15 minutes." : "Could not connect: " + (connectErr.text.trim().slice(-300) || "exit " + code);
            root.refreshStatus(); root._load();
        }
    }
    /// Google: its sign-in happens in a browser, so it runs in a terminal.
    function connectGoogle(clientId, secret) {
        googleProc.secret = secret;
        googleProc.command = ["sh", "-c", 'umask 077; d="${XDG_RUNTIME_DIR:-/tmp}"; cat > "$d/vitrum-google.secret"', "_"];
        googleProc.clientId = clientId;
        googleProc.running = true;
    }
    // The secret goes through a private file; the terminal reads it from there.
    Process {
        id: googleProc
        property string secret: ""
        property string clientId: ""
        stdinEnabled: true
        onStarted: { write(secret); secret = ""; stdinEnabled = false; }
        onExited: Quickshell.execDetached(["kitty", "--title", "Google Calendar", "-e", "sh", "-c",
            'f="${XDG_RUNTIME_DIR:-/tmp}/vitrum-google.secret"; s=$(cat "$f"); rm -f "$f"; vitrum-calendar google "$1" "$s"; echo; echo "Press Enter to close."; read -r _',
            "_", googleProc.clientId])
    }
    function disconnect() { Quickshell.execDetached(["vitrum-calendar", "disconnect"]); statusLater.restart(); }
    Timer { id: statusLater; interval: 800; onTriggered: root.refreshStatus() }
}
