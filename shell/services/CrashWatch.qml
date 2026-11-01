pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/crashes.js" as Lib

/*
 * Says when the shell crashed: a critical notification once it is back, with
 * the cause and the time. vitrum doctor lists the reports.
 *
 * A crash after the first 10 s comes back by itself: Quickshell execs itself in
 * the same PID, past vitrum-shell, while a forked child writes the report. So
 * the report appears while this shell starts, and it looks three times instead
 * of once. (A crash in the first 10 s exits, and vitrum-startup restarts it.)
 * A report it still misses is told on the next start.
 *
 * Only new reports count, so a normal restart says nothing. The time of the
 * last one told is kept in ~/.local/share/vitrum/last-crash.json.
 */
Singleton {
    id: root
    property var seen: null

    function _look(text) {
        const r = Lib.step(Lib.parseScan(text), seen, Date.now() / 1000);
        if (r.seen !== seen) {
            seen = r.seen;
            store.setText(JSON.stringify({ time: r.seen }));
        }
        if (r.fresh.length === 0) return;
        const d = new Date(r.fresh[0].time * 1000);
        const today = d.toDateString() === new Date().toDateString();
        const n = Lib.notice(r.fresh, Qt.formatDateTime(d, today ? "HH:mm" : "yyyy-MM-dd HH:mm"));
        Notifs.injectCritical("Shell", n.summary, n.body);
    }

    FileView {
        id: store
        path: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/vitrum/last-crash.json"
        printErrors: false
        onLoaded: {
            try {
                const t = JSON.parse(text()).time;
                if (typeof t === "number") root.seen = t;
            } catch (e) {}
        }
    }

    // The newest reports, without their long log tail.
    Process {
        id: scan
        command: ["sh", "-c", 'd="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/crashes"; ls -1t "$d"/report.txt "$d"/*/report.txt 2>/dev/null | head -n 12 | while IFS= read -r f; do printf "@@ %s\\n" "$(date -r "$f" +%s)"; sed -n "/^===== Instance Information/,/^===== Log Tail/p" "$f" | head -n 60; done']
        stdout: StdioCollector { onStreamFinished: root._look(text) }
    }
    // 5 s, 20 s and 65 s after the start.
    Timer {
        interval: 5000; repeat: true; running: true
        onTriggered: {
            if (!scan.running) scan.running = true;
            if (interval >= 45000) stop();
            else interval *= 3;
        }
    }
}
