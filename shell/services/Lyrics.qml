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
    // Turned on: found for what plays now; off: gone from the bar and the lock as well.
    readonly property bool enabled: Settings.get("media.lyrics", true)
    onEnabledChanged: fetchLater.restart()
    // Players change title and artist one after the other: ask once they settle.
    Timer { id: fetchLater; interval: 400; onTriggered: root.fetch() }

    function _track() { return { title: Media.title, artist: Media.artist, album: Media.album, length: Media.length }; }

    function fetch() {
        lines = []; plain = ""; index = -1;
        if (!key || !enabled) { state = "none"; return; }
        const asks = Lib.attempts(_track());
        if (!asks.length) { state = "missing"; return; }
        state = "loading";
        // Asked again when this one ends (onExited); it may be retrying for a while.
        if (proc.running) { if (proc.wanted !== key) proc.running = false; return; }
        proc.wanted = key;
        proc.track = _track();
        proc.file = cacheDir + "/" + Qt.md5(key) + ".json";
        // Timed lyrics in the cache stay. Plain text or nothing is good for two
        // weeks (lrclib grows), older ones ("checked" missing) are asked again.
        // Asks in turn until something has timed lines. lrclib often answers
        // 503 for a moment: that is tried again, and is no answer about the song.
        proc.command = ["sh", "-c",
            'f="$1"; shift; mkdir -p "$(dirname "$f")"; ' +
            'if [ -s "$f" ] && { grep -q "\\"syncedLyrics\\":\\"" "$f" || { grep -q "\\"checked\\"" "$f" && [ -n "$(find "$f" -mtime -14)" ]; }; }; then ' +
            '  printf "cached\\t"; tr "\\n" " " < "$f"; echo; exit 0; fi; ' +
            't="$f.tmp"; for a in "$@"; do for w in 0 2 5; do sleep $w; ' +
            '  code=$(curl -sS --max-time 8 -A "vitrum (https://github.com)" -o "$t" -w "%{http_code}" "https://lrclib.net/api/$a"); ' +
            '  case "$code" in 200|404) break ;; esac; done; ' +
            '  printf "%s\\t" "$code"; tr "\\n" " " < "$t" 2>/dev/null; echo; ' +
            '  if [ "$code" = 200 ] && grep -q "\\"syncedLyrics\\":\\"" "$t"; then break; fi; done; rm -f "$t"',
            "_", proc.file].concat(asks);
        proc.running = true;
    }
    Process {
        id: proc
        property string wanted: ""
        property var track: ({})
        property string file: ""
        onExited: if (wanted !== root.key && root.key) fetchLater.restart()
        stdout: StdioCollector {
            onStreamFinished: {
                if (proc.wanted !== root.key || !root.enabled) return;
                const a = Lib.parseAnswers(text);
                const found = Lib.best(a.items, proc.track);
                if (!a.cached && !a.flaky)
                    Quickshell.execDetached(["sh", "-c", 'printf "%s" "$2" > "$1.new" && mv -f "$1.new" "$1"', "_", proc.file,
                                             JSON.stringify(Lib.cacheRecord(found, Date.now()))]);
                const synced = Lib.parseLrc(found ? found.syncedLyrics : "");
                if (synced.length) { root.lines = synced; root.state = "synced"; root._tick(); }
                else if (found && found.plainLyrics) { root.plain = found.plainLyrics; root.state = "plain"; }
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
    // Not in a game: five ticks a second for a line nobody sees.
    Timer { interval: 200; repeat: true; running: root.users > 0 && root.lines.length > 0 && Media.playing && !GameMode.active; onTriggered: root._tick() }
}
