pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../lib/screentime.js" as Lib

/*
 * Screen time: how long each app has had the focus today (and the last two
 * weeks), for the desktop widget. The focused window (Niri) is timed, not
 * while the screen is locked or nobody is there (two minutes without input;
 * a playing video holds that off, through its idle inhibitor).
 *
 * Counted only while a screen-time widget is on the desktop: nothing is
 * recorded for someone who never asked for it. Kept, a minute at a time, in
 * ~/.local/share/vitrum/screentime.json ({ days: { "YYYY-MM-DD": { appId: s } } }).
 */
Singleton {
    id: root

    // The Settings app shares this code: only the shell counts.
    readonly property bool inShell: !Quickshell.env("VITRUM_NO_THEME")
    readonly property bool on: inShell && (Settings.get("widgets.items", []) || []).some(i => i && i.type === "screentime")

    property var days: ({})
    property bool loaded: false
    property string todayKey: Lib.dayKey(Date.now())
    readonly property var today: days[todayKey] || ({})

    readonly property int idleSeconds: 120
    readonly property string app: Niri.focusedWindow ? (Niri.focusedWindow.appId || "") : ""
    readonly property bool away: idle.isIdle || UiState.locked
    readonly property bool counting: on && loaded && app !== "" && !away

    // The stretch being timed: since when, and for which app.
    property real since: 0
    property string sinceApp: ""

    /// Credits the open stretch up to `end` (ms, default now) and starts the next.
    function flush(end) {
        const now = Date.now();
        const to = Math.min(now, end || now);
        if (since > 0 && sinceApp && to > since)
            days = Lib.prune(Lib.credit(days, sinceApp, since, to), now, 14);
        todayKey = Lib.dayKey(now);
        since = counting ? now : 0;
        sinceApp = counting ? app : "";
        if (dirty()) store.setText(JSON.stringify({ days: days }));
    }
    property string _saved: ""
    function dirty() { const s = JSON.stringify(days); if (s === _saved) return false; _saved = s; return true; }

    onAppChanged: flush()
    onCountingChanged: {
        // Gone idle: the last two minutes had nobody at the screen.
        if (!counting && idle.isIdle) flush(Date.now() - idleSeconds * 1000);
        else flush();
    }
    // A minute at a time: the widget stays current, and a crash loses little.
    Timer { interval: 60000; repeat: true; running: root.counting; onTriggered: root.flush() }

    IdleMonitor {
        id: idle
        enabled: root.on
        timeout: root.idleSeconds
        respectInhibitors: true
    }

    FileView {
        id: store
        path: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/vitrum/screentime.json"
        printErrors: false
        onLoaded: {
            try { root.days = Lib.sanitize(JSON.parse(text())); } catch (e) { root.days = ({}); }
            root._saved = JSON.stringify(root.days);
            root.loaded = true;
        }
        onLoadFailed: { root.days = ({}); root.loaded = true; }
    }
}
