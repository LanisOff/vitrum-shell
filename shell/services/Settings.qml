pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/settings.js" as Lib

/*
 * Settings — ~/.config/vitrum/settings.json merged over the shipped defaults.
 *
 * The file is the contract: the Settings app writes it, the shell reacts, and
 * editing it by hand works the same. A key with the wrong type or an unknown
 * value falls back to its default (with a warning); a file that is not JSON
 * keeps the last good values and reports the error — the shell never dies on
 * a bad settings file. A change made while the file is broken saves the
 * broken file as settings.json.broken first, so nothing typed by hand is lost.
 *
 * After every applied change vitrum-theme re-renders the palette and niri's
 * generated config (debounced).
 */
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.config/vitrum/settings.json"
    readonly property string dataDir: Qt.resolvedUrl("../data/").toString().replace("file://", "")

    property var defaults: ({})
    property var enums: ({})
    property var user: ({})               // validated user values, as written
    property var values: ({})             // defaults ← user
    property var warnings: []
    property string error: ""
    property bool ready: false
    property bool _defaultsLoaded: false
    property bool _enumsLoaded: false

    signal changed()

    function get(p, fallback) { return Lib.get(values, p, fallback); }

    // An app (Settings) never starts from a broken file: it has no good copy of
    // its own, and writing would replace everything with one key. It says so
    // instead; Advanced is where the file gets fixed.
    readonly property bool _app: !!Quickshell.env("VITRUM_NO_THEME")
    signal writeRefused()
    function set(p, value) {
        if (_app && error) { writeRefused(); return; }
        user = Lib.set(user, p, value);
        _apply();
        writeTimer.restart();
    }

    function _apply() {
        values = Lib.deepMerge(defaults, user);
        changed();
        themeTimer.restart();
    }

    function _parse(text) {
        let raw;
        try {
            raw = text.trim().length ? JSON.parse(text) : {};
        } catch (e) {
            error = "settings.json is not valid JSON: " + e.message + " — keeping the last good settings";
            console.warn("vitrum:", error);
            if (!ready) { user = {}; _apply(); ready = true; }   // first load: defaults
            return;
        }
        const r = Lib.validate(raw, defaults, enums);
        error = "";
        warnings = r.warnings;
        for (const w of r.warnings) console.warn("vitrum settings:", w);
        user = r.value;
        _apply();
        ready = true;
    }

    // -------------------------------------------------------- shipped data --

    FileView {
        path: root.dataDir + "settings.defaults.json"
        onLoaded: { root.defaults = JSON.parse(text()); root._defaultsLoaded = true; }
    }
    FileView {
        path: root.dataDir + "settings.enums.json"
        onLoaded: { root.enums = JSON.parse(text()); root._enumsLoaded = true; }
    }

    // ----------------------------------------------------------- the file --

    FileView {
        id: userFile
        // Only once defaults and enums are in: user values are validated against them.
        path: root._defaultsLoaded && root._enumsLoaded ? root.path : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root._parse(text())
        onLoadFailed: err => {
            // No file yet: defaults are the settings.
            root.user = {};
            root._apply();
            root.ready = true;
        }
    }

    Timer {
        id: writeTimer
        interval: 400
        onTriggered: {
            if (root.error) { keepBroken.running = true; return; }   // writes after the copy
            root._write();
        }
    }
    function _write() { userFile.setText(JSON.stringify(root.user, null, 2) + "\n"); }
    Process {
        id: keepBroken
        command: ["sh", "-c", 'cp -f "$1" "$1.broken"', "_", root.path]
        onExited: { root.error = ""; root._write(); }
    }

    // ------------------------------------------------------------- theme ---

    /// Re-render the palette and everything themed (the scheme flipped).
    function retheme() { themeTimer.restart(); }

    // A change during a run is not lost: it runs again when the current one ends.
    property bool _themeAgain: false
    Timer {
        id: themeTimer
        interval: 600
        // The apps (VITRUM_NO_THEME) leave it to the shell, which sees the same file change.
        onTriggered: { if (Quickshell.env("VITRUM_NO_THEME")) return; if (theme.running) root._themeAgain = true; else theme.running = true; }
    }
    Process {
        id: theme
        command: ["vitrum-theme", "--quiet"]
        stderr: StdioCollector { onStreamFinished: if (text.length) console.warn("vitrum-theme:", text) }
        onExited: if (root._themeAgain) { root._themeAgain = false; theme.running = true; }
    }
}
