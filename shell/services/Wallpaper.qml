pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/wallpaper.js" as Lib

/*
 * The wallpaper on every output.
 *
 *   images   awww (transition wallpaper.transition: grow from where it was
 *            asked, fade, none) — or drawn by the shell itself
 *            (modules/wallpaper) when parallax is on or awww is missing
 *   videos   mpvpaper, one per output, silent and looping; paused through
 *            mpv's IPC socket while windows cover the output
 *            (wallpaper.live.pauseWhenCovered)
 *
 * Changing it is a settings change (wallpaper.path / perOutput), so
 * vitrum-theme re-reads the palette from the new image (or a video's poster
 * frame) like after any other change.
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string runtime: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/vitrum-wallpaper-" + (Quickshell.env("WAYLAND_DISPLAY") || "0")
    readonly property var conf: Settings.get("wallpaper", ({}))
    readonly property bool parallax: Settings.get("wallpaper.parallax", false)
    readonly property bool live: Settings.get("wallpaper.live.enabled", true)
    readonly property string transition: Settings.get("wallpaper.transition", "grow")
    readonly property string dir: Lib.expand(Settings.get("wallpaper.dir", "~/Pictures/Wallpapers"), home)

    property var installed: ({})
    property bool checked: false
    /// The shell draws images itself: parallax, or no awww to do it.
    readonly property bool shellDraws: checked && (parallax || !installed.awww)

    function pathFor(output) { return Lib.pathFor(conf, output, home); }
    function videoOn(output) { const p = pathFor(output); return live && Lib.isVideo(p) && !!installed.mpvpaper; }

    /// Where the next transition grows from: { output, x, y } (output-local), once.
    property var origin: null

    /// output "" sets the shared wallpaper (and drops per-output ones).
    function set(path, output, pos) {
        origin = pos && output ? { output: output, x: pos.x, y: pos.y } : null;
        if (output) {
            const per = Object.assign({}, Settings.get("wallpaper.perOutput", {}));
            per[output] = path;
            Settings.set("wallpaper.perOutput", per);
        } else {
            Settings.set("wallpaper.perOutput", {});
            Settings.set("wallpaper.path", path);
        }
    }

    // ---------------------------------------------------- applying ---

    property var applied: ({})       // output → "kind:path" last applied
    Connections { target: Settings; function onValuesChanged() { Qt.callLater(root.applyAll); } }
    Connections { target: Quickshell; function onScreensChanged() { Qt.callLater(root.applyAll); } }
    onShellDrawsChanged: Qt.callLater(applyAll)

    function applyAll() {
        if (!checked || !Settings.ready) return;
        const next = {};
        for (const s of Quickshell.screens) {
            const out = s.name, p = pathFor(out);
            const kind = !p ? "none" : videoOn(out) ? "video" : shellDraws ? "shell" : "awww";
            const key = kind + ":" + p;
            next[out] = key;
            if (applied[out] === key) continue;
            if (kind === "video") { startVideo(out, p); if (installed.awww) posterUnder(out, p); }
            else stopVideo(out);
            if (kind === "awww") {
                const o = origin && origin.output === out ? origin : null;
                const first = applied[out] === undefined;      // at startup: no transition
                awww(Lib.awwwArgs(p, out, first ? "none" : transition, o, 0.9));
            }
        }
        applied = next;
        origin = null;
        // The shell draws over nothing: an awww surface left behind would cover it.
        if (shellDraws && installed.awww) run(["awww", "kill"]);
    }

    // An awww command, after making sure its daemon runs (the session starts it,
    // but parallax kills it and turning parallax off must bring it back). A
    // daemon that has just started may not know the outputs yet: retried.
    function awww(args) {
        run(["sh", "-c", 'awww query >/dev/null 2>&1 || { setsid -f awww-daemon >/dev/null 2>&1; i=0; until awww query >/dev/null 2>&1 || [ $i -ge 30 ]; do sleep 0.1; i=$((i+1)); done; }; i=0; until "$@" 2>/dev/null; do [ $i -ge 20 ] && exit 1; sleep 0.5; i=$((i+1)); done', "_"].concat(args));
    }

    // ------------------------------------------------------- videos ---

    // The video's first frame on awww's layer, under mpvpaper: while the
    // player starts (every shell start, every login) that frame shows, not
    // whatever picture awww held before — the old wallpaper flashed.
    readonly property string posters: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/vitrum/posters"
    function posterUnder(output, path) {
        const poster = posters + "/" + Qt.md5(path) + ".png";
        run(["sh", "-c", 'p="$1"; poster="$2"; shift 2; mkdir -p "${poster%/*}"; ' +
             '[ -s "$poster" ] || ffmpeg -y -loglevel error -ss 0 -i "$p" -frames:v 1 "$poster" || exit 0; ' +
             'awww query >/dev/null 2>&1 || exit 0; exec "$@"', "_", path, poster].concat(Lib.awwwArgs(poster, output, "none", null, 0.1)));
    }

    property var players: ({})       // output → { proc, socket, paused }
    Component { id: playerProc; Process {} }
    Component { id: playerSocket; Socket {} }

    function socketPath(output) { return runtime + "/mpv-" + output + ".sock"; }
    function startVideo(output, path) {
        stopVideo(output);
        const sock = socketPath(output);
        const proc = playerProc.createObject(root, { command: ["sh", "-c", 'mkdir -p "$1" && shift && exec "$@"', "_", runtime].concat(Lib.mpvArgs(path, output, sock)) });
        proc.running = true;
        const p = Object.assign({}, players);
        p[output] = { proc: proc, socket: null, paused: false };
        players = p;
        Qt.callLater(updatePause);
    }
    function stopVideo(output) {
        const pl = players[output];
        if (!pl) return;
        if (pl.socket) pl.socket.destroy();
        pl.proc.running = false;
        pl.proc.destroy();
        const p = Object.assign({}, players);
        delete p[output];
        players = p;
    }
    function setPaused(output, paused) {
        const pl = players[output];
        if (!pl || pl.paused === paused) return;
        if (!pl.socket) pl.socket = playerSocket.createObject(root, { path: socketPath(output) });
        pl.socket.connected = true;
        pl.socket.write(Lib.mpvPause(paused));
        pl.socket.flush();
        pl.paused = paused;
    }

    // Pause what nobody can see.
    Connections { target: Niri; function onWindowsChanged() { root.updatePause(); } function onWorkspacesChanged() { root.updatePause(); } }
    function updatePause() {
        const pause = Settings.get("wallpaper.live.pauseWhenCovered", true);
        const top = Settings.get("bar.position", "top") === "top" ? 40 : 0;
        for (const out in players) {
            const ws = Niri.activeWorkspaceOn(out), o = Niri.outputs[out];
            if (!ws || !o) continue;
            const tiles = Niri.windowsOn(ws.id).filter(w => w.layout && w.layout.tile_size).map(w => ({
                col: w.layout.pos_in_scrolling_layout ? w.layout.pos_in_scrolling_layout[0] : -1,
                w: w.layout.tile_size[0], h: w.layout.tile_size[1], floating: !!w.floating }));
            setPaused(out, pause && Lib.covered(tiles, { w: o.width, h: o.height }, top));
        }
    }

    // ------------------------------------------------------- folder ---

    /// Next/previous/random image or video in wallpaper.dir.
    function cycle(dirStep) {
        const p = listProc.createObject(root, { command: ["sh", "-c",
            'find "$1" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" -o -iname "*.gif" \\) | sort', "_", dir] });
        p.listed.connect(files => {
            const cur = pathFor(Niri.focusedOutput || (Quickshell.screens[0] ? Quickshell.screens[0].name : ""));
            const pick = dirStep === 0 ? files[Math.floor(Math.random() * files.length)] || "" : Lib.step(files, cur, dirStep);
            if (pick) set(pick, "", null);
            p.destroy();
        });
        p.running = true;
    }
    Component {
        id: listProc
        Process {
            id: lp
            signal listed(var files)
            stdout: StdioCollector { onStreamFinished: lp.listed(text.split("\n").filter(s => s)) }
        }
    }

    // ------------------------------------------------------ helpers ---

    function run(cmd) {
        const p = oneShot.createObject(root, { command: cmd });
        p.exited.connect(() => Qt.callLater(() => p.destroy()));
        p.running = true;
    }
    Component { id: oneShot; Process {} }

    Process {
        running: true
        command: ["sh", "-c", "for c in awww awww-daemon mpvpaper; do command -v $c >/dev/null && echo $c; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                for (const n of text.split("\n")) if (n) m[n] = true;
                root.installed = m;
                root.checked = true;
                Qt.callLater(root.applyAll);
            }
        }
    }
}
