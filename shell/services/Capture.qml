pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/capture.js" as Lib

/*
 * Screenshots, OCR and screen recording.
 *
 * Opening freezes every screen first (grim, one file per output), so what is
 * selected is what was on screen when the key was pressed; the overlay
 * (modules/capture) draws the frozen frame and crops from it. Delayed
 * captures, windows and recordings are taken live instead.
 *
 * Files go to capture.dir / capture.videoDir; a screenshot is also copied to
 * the clipboard (capture.copy). The last one floats as a thumbnail.
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    // Per display: a nested test session must not share frames with the real one.
    readonly property string runtime: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/vitrum-capture-" + (Quickshell.env("WAYLAND_DISPLAY") || "0")
    function expand(p) { return p.replace(/^~(?=\/|$)/, home); }
    readonly property string dir: expand(Settings.get("capture.dir", "~/Pictures/Screenshots"))
    readonly property string videoDir: expand(Settings.get("capture.videoDir", "~/Videos/Recordings"))

    // What the overlay starts with, and what it changes.
    property string kind: "photo"              // photo | video | ocr
    property string mode: Settings.get("capture.mode", "area")
    property int delay: Settings.get("capture.delay", 0)
    /// Releasing the mouse takes the shot (the region/OCR keys); otherwise the
    /// selection stays adjustable until Enter or the capture button.
    property bool immediate: false

    signal selectionClaimed(string screenName)     // one selection across all screens
    signal testSelect(rect r, bool take)                    // vitrum-ipc debug captureselect

    property int frozenStamp: 0
    function frozen(screenName) { return "file://" + runtime + "/frozen-" + screenName + ".png"; }

    property int windowId: -1
    property int countdown: 0
    property var last: null                    // { path, kind, stamp }
    property var installed: ({})

    // ------------------------------------------------------------ opening ---

    function open(opts) {
        if (UiState.capture || countdown > 0) return;
        kind = opts.kind || "photo";
        mode = opts.mode || Settings.get("capture.mode", "area");
        delay = opts.delay !== undefined ? opts.delay : Settings.get("capture.delay", 0);
        immediate = !!opts.immediate;
        // While the overlay holds the keyboard niri reports no focused window; remember it now.
        windowId = Niri.focusedWindowId;
        UiState.closeAll();
        // Let panels finish closing so they are not in the frozen frame.
        freezeDelay.restart();
    }
    Timer { id: freezeDelay; interval: 180; onTriggered: root.freeze() }

    function freeze() {
        const names = Quickshell.screens.map(s => s.name);
        freezer.command = ["sh", "-c", 'd="$1"; mkdir -p "$2"; shift 2; mkdir -p "$d" && for o; do grim -o "$o" "$d/frozen-$o.png"; done', "_", runtime, dir].concat(names);
        freezer.running = true;
    }
    Process {
        id: freezer
        onExited: (code) => {
            root.frozenStamp++;
            if (code !== 0) Notifs.inject("Capture", "Could not capture the screen", "grim failed — the selection is drawn over the live screen.");
            UiState.capture = true;
        }
    }

    function cancel() { UiState.capture = false; }

    // ------------------------------------------------------------- photos ---

    function newPath(k) { return (k === "video" ? videoDir : dir) + "/" + Lib.fileName(k, new Date()); }
    function ocrPath() { return runtime + "/ocr.png"; }

    /// The overlay saved a crop of the frozen frame to `path`.
    function saved(path) {
        UiState.capture = false;
        if (kind === "ocr") { ocr(path); return; }
        Sounds.play("screenshot");
        if (Settings.get("capture.copy", true)) run(["sh", "-c", 'setsid -f wl-copy --type image/png < "$1" >/dev/null 2>&1', "_", path]);
        last = { path: path, kind: "photo", stamp: Date.now() };
    }

    /// The whole of one screen, from its frozen frame.
    function shootScreen(name) {
        const path = kind === "ocr" ? ocrPath() : newPath("photo");
        const p = run(["sh", "-c", 'mkdir -p "$(dirname "$2")" && cp "$1" "$2"', "_", runtime + "/frozen-" + name + ".png", path]);
        p.exited.connect(code => { if (code === 0) root.saved(path); else root.failed("Could not save the screenshot"); });
    }

    /// The focused window — niri renders it without anything on top.
    function shootWindow() {
        UiState.capture = false;
        const id = windowId >= 0 && Niri.windows[windowId] ? windowId : Niri.focusedWindowId;
        if (id < 0) { failed("No window is focused"); return; }
        const path = kind === "ocr" ? ocrPath() : newPath("photo");
        const p = run(["sh", "-c", 'mkdir -p "$(dirname "$2")" && "$1" msg action screenshot-window --id "$3" --write-to-disk true --path "$2" && for i in 1 2 3 4 5 6 7 8 9 10; do [ -s "$2" ] && exit 0; sleep 0.1; done; exit 1',
                       "_", Niri.bin, path, String(id)]);
        p.exited.connect(code => { if (code === 0) root.saved(path); else root.failed("niri did not save the window"); });
    }

    // Delayed: the overlay is gone, the screen is live again; take it after the countdown.
    property var pending: null
    function later(what) {
        UiState.capture = false;
        pending = what;
        if (delay <= 0) { afterCountdown.restart(); return; }   // still wait for the overlay to fade
        countdown = delay;
        tick.restart();
    }
    Timer {
        id: tick
        interval: 1000; repeat: true
        onTriggered: {
            root.countdown--;
            // The last second ends early so the countdown itself is gone from the screen.
            if (root.countdown <= 0) { stop(); root.countdown = 0; Qt.callLater(() => afterCountdown.restart()); }
        }
    }
    Timer { id: afterCountdown; interval: 250; onTriggered: root.runPending() }
    function cancelCountdown() { tick.stop(); countdown = 0; pending = null; }

    function runPending() {
        const w = pending; pending = null;
        if (!w) return;
        if (kind === "video") { record(w.screen, w.rect); return; }
        if (w.what === "window") { shootWindow(); return; }
        const path = kind === "ocr" ? ocrPath() : newPath("photo");
        const args = w.rect ? ["-g", Lib.geometry(w.rect, w.origin)] : ["-o", w.screen];
        const p = run(["sh", "-c", 'p="$1"; shift; mkdir -p "$(dirname "$p")" && grim "$@" "$p"', "_", path].concat(args));
        p.exited.connect(code => { if (code === 0) root.saved(path); else root.failed("grim failed"); });
    }

    // ---------------------------------------------------------------- OCR ---

    function ocr(path) {
        const p = run(["sh", "-c", 't=$(tesseract "$1" - -l "$2" 2>/dev/null) || exit 2; [ -n "$(printf %s "$t" | tr -d "[:space:]")" ] || exit 3; printf %s "$t" | setsid -f wl-copy >/dev/null 2>&1; printf %s "$t"',
                       "_", path, Settings.get("capture.ocrLanguages", "eng")], true);
        p.done.connect((code, out) => {
            if (code === 0) Notifs.inject("Capture", "Text copied", out.trim().slice(0, 240));
            else if (code === 3) Notifs.inject("Capture", "No text found", "");
            else root.failed(root.installed.tesseract ? "Text recognition failed (capture.ocrLanguages: " + Settings.get("capture.ocrLanguages", "eng") + ")" : "tesseract is not installed");
        });
    }

    // ---------------------------------------------------------- recording ---

    property var recordingOpts: null
    property string recorder: ""
    property real recordingSince: 0

    /// rect null → the whole screen.
    function record(screenName, rect) {
        UiState.capture = false;
        const tool = Lib.pickRecorder(Settings.get("capture.recorder", "auto"), installed);
        if (!tool) { failed("No screen recorder installed", "Install gpu-screen-recorder or wf-recorder."); return; }
        const s = Quickshell.screens.find(x => x.name === screenName);
        recordingOpts = { output: screenName, origin: { x: s ? s.x : 0, y: s ? s.y : 0 }, rect: rect, file: newPath("video"),
                          audio: Lib.audioMode(Settings.get("capture.audio", true), Settings.get("capture.mic", false)),
                          fps: Settings.get("capture.fps", 60) };
        switched = false;
        startRecorder(tool);
    }

    // wf-recorder records one device: the computer's sound and the microphone
    // both go into a temporary sink (loopbacks of the output's monitor and the
    // default source), removed when the recording ends. Defaults are untouched.
    property bool mixing: false
    function _mixUp() {
        mixing = true;
        return run(["sh", "-c",
             'out=$(pactl get-default-sink) && mic=$(pactl get-default-source) && ' +
             'pactl load-module module-null-sink sink_name="$1" sink_properties=device.description=vitrum-recording >/dev/null && ' +
             'pactl load-module module-loopback source="$out.monitor" sink="$1" latency_msec=30 >/dev/null && ' +
             'pactl load-module module-loopback source="$mic" sink="$1" latency_msec=30 >/dev/null', "_", Lib.MIX_SINK], true);
    }
    function _mixDown() {
        if (!mixing) return;
        mixing = false;
        // Every module that mentions our sink: the loopbacks, then the sink itself.
        run(["sh", "-c", 'pactl list short modules | awk -v s="$1" \'index($0, s) {print $1}\' | sort -rn | xargs -r -n1 pactl unload-module', "_", Lib.MIX_SINK]);
    }
    function startRecorder(tool) {
        recorder = tool;
        // The mix must exist before the recorder opens it.
        if (Lib.needsMix(tool, recordingOpts.audio)) {
            if (!mixing) { _mixUp().done.connect(() => root._launch()); return; }
        } else _mixDown();
        _launch();
    }
    function _launch() {
        recordingSince = Date.now();
        // The recorder's own messages go to recorder.log, for when it fails.
        recProc.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" "$(dirname "$2")" && f="$2" && shift 2 && exec "$@" > "$f" 2>&1', "_",
                           recordingOpts.file, runtime + "/recorder.log"].concat(Lib.recorderCommand(recorder, recordingOpts));
        recProc.running = true;
        UiState.recording = true;
        stalled = false;
        stallCheck.restart();
    }
    // A recorder that has written nothing a few seconds in is not going to:
    // gpu-screen-recorder hung like that on niri + NVIDIA, silent, until it was
    // killed at stop — no file. It is stopped, and the other one gets a turn.
    property bool switched: false
    property bool stalled: false
    Timer {
        id: stallCheck
        interval: 5000
        onTriggered: {
            if (!recProc.running) return;
            const check = root.run(["sh", "-c", '[ -s "$1" ]', "_", root.recordingOpts.file], true);
            check.done.connect(code => {
                if (code === 0 || !recProc.running) return;
                root.stalled = true;
                recProc.signal(9);
            });
        }
    }
    // SIGINT lets both recorders finish the file; one stuck starting up ignores it, so it escalates.
    // wf-recorder finishes on the next frame with damage, which on a still screen can take a while.
    property bool forcedStop: false
    function stop() {
        if (!recProc.running) return;
        forcedStop = false;
        recProc.signal(2);
        escalate.signalNo = 15;
        escalate.interval = recorder === "wf-recorder" ? 30000 : 4000;
        escalate.restart();
    }
    Timer {
        id: escalate
        property int signalNo: 15
        interval: 4000
        onTriggered: {
            if (!recProc.running) return;
            root.forcedStop = true;
            recProc.signal(signalNo);
            if (signalNo === 15) { signalNo = 9; interval = 4000; restart(); }
        }
    }
    Connections { target: UiState; function onStopRecordingRequested() { root.stop(); } }

    Process {
        id: recProc
        onExited: (code) => {
            stallCheck.stop();
            const quick = Date.now() - root.recordingSince < 2000;
            const stalled = root.stalled;
            root.stalled = false;
            // A recorder that cannot capture here (exits at once, or writes nothing): the other one, once.
            if ((quick || stalled) && !root.switched && Settings.get("capture.recorder", "auto") === "auto") {
                const other = Lib.otherRecorder(root.recorder, root.installed);
                if (other) { root.switched = true; root.startRecorder(other); return; }
            }
            UiState.recording = false;
            root._mixDown();
            if (stalled) { escalate.stop(); root.forcedStop = false; root.failed(root.recorder + " did not start recording", "Nothing was written in 5 s. See " + root.runtime + "/recorder.log, or pick the other recorder in Settings › Capture."); return; }
            const forced = root.forcedStop;
            root.forcedStop = false;
            escalate.stop();
            if (quick) { root.failed(root.recorder + " stopped at once (exit " + code + ")"); return; }
            if (forced) { root.failed(root.recorder + " did not stop when asked", "The recording may be incomplete: " + root.recordingOpts.file); return; }
            // Saved only if the file is there and not empty.
            const file = root.recordingOpts.file;
            const check = root.run(["sh", "-c", '[ -s "$1" ] || { tail -n 3 "$2"; exit 1; }', "_", file, root.runtime + "/recorder.log"], true);
            check.done.connect((c, out) => {
                if (c === 0) root.last = { path: file, kind: "video", stamp: Date.now() };
                else root.failed(root.recorder + " saved nothing", out.trim() || "See " + root.runtime + "/recorder.log");
            });
        }
    }

    // ------------------------------------------------------------ helpers ---

    function failed(summary, body) { Notifs.inject("Capture", summary, body || ""); }

    // The picture open in vitrum's editor (modules/capture/ImageEditor.qml), or "".
    property string editing: ""
    property int editStamp: 0
    function edit(path) {
        const ed = Settings.get("capture.editor", "vitrum");
        if (ed === "vitrum") { editStamp++; editing = path; }
        else if (ed === "satty" && installed.satty) run(["satty", "--filename", path, "--output-filename", path, "--copy-command", "wl-copy"]);
        else run(["xdg-open", path]);
    }
    function editDone(saved, copied) {
        editing = "";
        if (saved) { last = { path: saved, kind: "photo", stamp: Date.now() }; Notifs.inject("Capture", "Edited picture saved", saved.replace(home, "~")); }
        else if (copied) Notifs.inject("Capture", "Edited picture copied", "");
    }
    function showInFolder(path) { run(["xdg-open", path.replace(/\/[^/]*$/, "")]); }
    function copy(path) { run(["sh", "-c", 'setsid -f wl-copy --type image/png < "$1" >/dev/null 2>&1', "_", path]); }

    /// A one-shot process, destroyed when it exits. collect: keep stdout in `out`.
    /// Anything that must outlive it (wl-copy serving the clipboard) is started with setsid -f.
    function run(cmd, collect) {
        const p = (collect ? collectingProc : proc).createObject(root, { command: cmd });
        (collect ? p.done : p.exited).connect(() => Qt.callLater(() => p.destroy()));
        p.running = true;
        return p;
    }
    Component { id: proc; Process {} }
    // Emits done(code, stdout) once both the exit and the end of output are in.
    Component {
        id: collectingProc
        Process {
            id: cp
            property string out: ""
            property int code: -1
            property bool streamDone: false
            signal done(int code, string out)
            stdout: StdioCollector { onStreamFinished: { cp.out = text; cp.streamDone = true; if (cp.code >= 0) cp.done(cp.code, cp.out); } }
            onExited: (c) => { cp.code = c; if (cp.streamDone) cp.done(cp.code, cp.out); }
        }
    }

    // What is installed decides the recorder, the editor and whether OCR can work.
    Process {
        running: true
        command: ["sh", "-c", "for c in gpu-screen-recorder wf-recorder satty tesseract grim; do command -v $c >/dev/null && echo $c; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                for (const n of text.split("\n")) if (n) m[n] = true;
                root.installed = m;
            }
        }
    }
}
