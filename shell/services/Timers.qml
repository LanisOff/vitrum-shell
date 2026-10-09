pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/timers.js" as Lib

/*
 * Countdown timers and a pomodoro. Started from the launcher ("5m",
 * "pomodoro"); shown by the bar's timer island; a notification (and a sound)
 * when one ends. Kept in the runtime directory, so a shell restart does not
 * lose them; a logout does.
 */
Singleton {
    id: root

    /// [{ id, label, end (ms), seconds, kind: "timer" | "pomodoro", phase, round, paused, left }]
    property var list: []
    property real now: Date.now()
    readonly property var next: list.filter(t => !t.paused).sort((a, b) => a.end - b.end)[0] || list[0] || null
    function leftOf(t) { return t.paused ? t.left : Math.max(0, (t.end - now) / 1000); }

    function start(seconds, label) {
        _add({ id: Date.now(), label: label || Lib.label(seconds), end: Date.now() + seconds * 1000, seconds: seconds, kind: "timer" });
    }
    function startPomodoro() {
        list = list.filter(t => t.kind !== "pomodoro");
        const n = Lib.pomodoroNext(null, _pomo());
        _add({ id: Date.now(), label: "Focus", end: Date.now() + n.seconds * 1000, seconds: n.seconds, kind: "pomodoro", phase: n.phase, round: n.round });
    }
    function cancel(id) { list = list.filter(t => t.id !== id); _save(); }
    function togglePause(id) {
        list = list.map(t => {
            if (t.id !== id) return t;
            const c = Object.assign({}, t);
            if (t.paused) { c.paused = false; c.end = Date.now() + t.left * 1000; }
            else { c.paused = true; c.left = Math.max(0, (t.end - Date.now()) / 1000); }
            return c;
        });
        _save();
    }

    function _pomo() {
        return { work: Settings.get("timers.work", 25), short: Settings.get("timers.short", 5),
                 long: Settings.get("timers.long", 15), rounds: Settings.get("timers.rounds", 4) };
    }
    function _add(t) { list = list.concat([t]); _save(); }
    function _done(t) {
        if (t.kind === "pomodoro") {
            const n = Lib.pomodoroNext({ phase: t.phase, round: t.round }, _pomo());
            const msg = n.phase === "work" ? "Back to work — round " + n.round : n.phase === "long" ? "Long break" : "Short break";
            Notifs.inject("Pomodoro", msg, Lib.format(n.seconds) + " starts now.");
            list = list.map(x => x.id !== t.id ? x : Object.assign({}, x, {
                label: n.phase === "work" ? "Focus" : "Break", end: Date.now() + n.seconds * 1000, seconds: n.seconds, phase: n.phase, round: n.round }));
        } else {
            Notifs.inject("Timer", t.label + " is done", "");
            list = list.filter(x => x.id !== t.id);
        }
        Sounds.play("notification");
        _save();
    }

    Timer {
        interval: 250; repeat: true; running: root.list.length > 0
        onTriggered: {
            root.now = Date.now();
            for (const t of root.list) if (!t.paused && t.end <= root.now) { root._done(t); break; }
        }
    }

    readonly property string file: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/vitrum-timers.json"
    FileView {
        id: store
        path: root.file
        printErrors: false
        onLoaded: { try { const d = JSON.parse(text()); if (Array.isArray(d)) root.list = d; } catch (e) {} }
    }
    function _save() { store.setText(JSON.stringify(list)); }
}
