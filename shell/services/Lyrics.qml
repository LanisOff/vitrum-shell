pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/lyrics.js" as Lib

/*
 * Synced lyrics for what plays (lrclib.net, no account), cached per track in
 * ~/.cache/vitrum/lyrics. `index` follows the player's position while someone
 * shows them (subscribe/unsubscribe: the media panel, the bar, the lock screen).
 */
Singleton {
    id: root

    property var lines: []          // [{ t, text }]
    property string plain: ""       // unsynced lyrics, when that is all there is
    property int index: -1
    property string state: "none"   // none | loading | synced | plain | missing
    readonly property string current: index >= 0 && lines[index] ? lines[index].text : ""
    readonly property string next: index + 1 < lines.length ? lines[index + 1].text : ""

    property int users: 0
    function subscribe() { users++; }
    function unsubscribe() { users = Math.max(0, users - 1); }

    readonly property string key: Media.available && Media.title ? Media.artist + "\n" + Media.title : ""
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/vitrum/lyrics"
    onKeyChanged: fetchLater.restart()
    // Players change title and artist one after the other: ask once they settle.
    Timer { id: fetchLater; interval: 400; onTriggered: root.fetch() }

    function fetch() {
        lines = []; plain = ""; index = -1;
        if (!key || !Settings.get("media.lyrics", true)) { state = "none"; return; }
        const args = Lib.queryArgs({ title: Media.title, artist: Media.artist, album: Media.album, length: Media.length });
        if (!args) { state = "missing"; return; }
        state = "loading";
        if (proc.running) return;          // asked again when this one ends (onExited)
        proc.wanted = key;
        // Cached answers are reused; a 404 is cached as {} so it is not asked again.
        proc.command = ["sh", "-c",
            'f="$1"; shift; [ -s "$f" ] && exec cat "$f"; mkdir -p "$(dirname "$f")"; ' +
            'code=$(curl -sS --max-time 8 -A "vitrum (https://github.com)" -o "$f.tmp" -w "%{http_code}" --get "$@" https://lrclib.net/api/get); ' +
            'if [ "$code" = 200 ]; then mv -f "$f.tmp" "$f"; elif [ "$code" = 404 ]; then echo "{}" > "$f"; fi; rm -f "$f.tmp"; cat "$f" 2>/dev/null',
            "_", cacheDir + "/" + Qt.md5(key) + ".json"].concat(args);
        proc.running = true;
    }
    Process {
        id: proc
        property string wanted: ""
        onExited: if (wanted !== root.key && root.key) fetchLater.restart()
        stdout: StdioCollector {
            onStreamFinished: {
                if (proc.wanted !== root.key) return;
                let d = {};
                try { d = JSON.parse(text || "{}"); } catch (e) {}
                const synced = Lib.parseLrc(d.syncedLyrics || "");
                if (synced.length) { root.lines = synced; root.state = "synced"; root._tick(); }
                else if (d.plainLyrics) { root.plain = d.plainLyrics; root.state = "plain"; }
                else root.state = "missing";
            }
        }
    }

    function _tick() {
        if (!lines.length || !Media.current) return;
        // A little ahead: the line appears as it is sung, not after.
        const i = Lib.lineAt(lines, (Media.current.position || 0) + 0.25);
        if (i !== index) index = i;
    }
    Timer { interval: 200; repeat: true; running: root.users > 0 && root.lines.length > 0 && Media.playing; onTriggered: root._tick() }
}
