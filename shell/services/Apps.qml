pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * The application catalogue, and the fuzzy matcher Spotlight, Launchpad and
 * the Dock all share.
 *
 * DesktopEntries gives us the list; the scoring is ours, because the default
 * substring match ranks "Disk Usage Analyzer" above "Disk Utility" for the
 * query "disk u", which is exactly the case that matters.
 */
Singleton {
    id: root

    readonly property var all: {
        const out = [];
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay) continue;
            out.push({
                id: e.id,
                name: e.name,
                genericName: e.genericName || "",
                comment: e.comment || "",
                icon: e.icon || "application-x-executable",
                entry: e,
                keywords: (e.keywords || []).join(" "),
                categories: (e.categories || []).join(" "),
                startupClass: e.startupClass || ""
            });
        }
        out.sort((a, b) => a.name.localeCompare(b.name));
        return out;
    }

    /// Launch counts, so the ranking learns what this user actually opens.
    property var usage: ({})

    FileView {
        id: usageFile
        path: Quickshell.env("HOME") + "/.local/share/vitrum/usage.json"
        onLoaded: {
            try { root.usage = JSON.parse(text()); } catch (e) { root.usage = ({}); }
        }
        onLoadFailed: root.usage = ({})
    }

    Timer {
        id: usageWrite
        interval: 3000
        onTriggered: usageFile.setText(JSON.stringify(root.usage))
    }

    function launch(app) {
        if (!app) return;
        const key = app.id || app.name;
        const next = Object.assign({}, usage);
        next[key] = (next[key] || 0) + 1;
        usage = next;
        usageWrite.restart();

        if (app.entry) app.entry.execute();
        else runProc(["sh", "-c", app.exec || ""]);
    }

    // Detached: each launch is its own process (a shared one ignored new commands
    // while the last was still running), and apps outlive a shell restart.
    function runProc(cmdline) { Quickshell.execDetached(cmdline); }

    // ------------------------------------------------------------ search ---

    /*
     * Scoring, highest first:
     *   1000  exact name
     *    800  name starts with the query
     *    600  a word in the name starts with the query
     *    400  every query character appears in order in the name (subsequence)
     *    200  the query appears in keywords / generic name / comment
     * plus a small bonus for how often this app has been launched, which is
     * what breaks ties between "Files" and "File Roller".
     */
    function score(app, query) {
        // No query: what this user opens most comes first.
        if (!query) return 1 + Math.min(80, (usage[app.id || app.name] || 0) * 8);
        const q = query.toLowerCase();
        const name = app.name.toLowerCase();

        let s = 0;
        if (name === q) s = 1000;
        else if (name.indexOf(q) === 0) s = 800 - (name.length - q.length);
        else {
            const words = name.split(/[\s\-_.]+/);
            for (const w of words) {
                if (w.indexOf(q) === 0) { s = 600 - (name.length - q.length); break; }
            }
        }
        if (s === 0 && _subsequence(name, q)) s = 400 - (name.length - q.length);
        if (s === 0) {
            const hay = (app.keywords + " " + app.genericName + " " + app.comment).toLowerCase();
            if (hay.indexOf(q) >= 0) s = 200;
        }
        if (s === 0) return 0;

        const uses = usage[app.id || app.name] || 0;
        return s + Math.min(80, uses * 8);
    }

    function _subsequence(hay, needle) {
        let i = 0;
        for (let j = 0; j < hay.length && i < needle.length; j++) {
            if (hay[j] === needle[i]) i++;
        }
        return i === needle.length;
    }

    function search(query, limit) {
        const out = [];
        for (const app of all) {
            const s = score(app, query);
            if (s > 0) out.push({ app: app, score: s });
        }
        out.sort((a, b) => b.score - a.score || a.app.name.localeCompare(b.app.name));
        return out.slice(0, limit || 8).map(x => x.app);
    }

    /// Match a running window back to its desktop entry, for the Dock.
    function forAppId(appId) {
        if (!appId) return null;
        const lower = appId.toLowerCase();
        for (const a of all) {
            if (a.id.toLowerCase() === lower) return a;
            if (a.id.toLowerCase() === lower + ".desktop") return a;
            if (a.startupClass && a.startupClass.toLowerCase() === lower) return a;
        }
        // Reverse-DNS ids: org.gnome.Nemo -> nemo
        const tail = lower.split(".").pop();
        for (const a of all) {
            if (a.id.toLowerCase().split(".").pop().replace(/\.desktop$/, "") === tail) return a;
            if (a.name.toLowerCase() === tail) return a;
        }
        return null;
    }

    function iconFor(appId, fallback) {
        const a = forAppId(appId);
        return a ? a.icon : (fallback || "application-x-executable");
    }
}
