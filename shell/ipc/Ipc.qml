import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme

/*
 * The shell's IPC: keybinds and scripts call `vitrum-ipc <target> <function> [args]`.
 */
Scope {

    property var lockRef: null
    function screenNamed(name) {
        for (const s of Quickshell.screens) if (s.name === name) return s;
        return null;
    }
    function focusedScreen() { return screenNamed(Niri.focusedOutput) || Quickshell.screens[0]; }

    IpcHandler {
        target: "panel"
        // Open a bar panel on the focused screen, anchored at the top centre.
        function open(name: string): void {
            const s = focusedScreen();
            UiState.openPanel(name, s, Qt.rect(s.width / 2 - 60, Tokens.gap, 120, Tokens.islandHeight));
        }
        function close(): void { UiState.closePanel(); }
    }
    IpcHandler {
        target: "screencast"
        // vitrum-portal: an app wants to share the screen (ScreenShare answers).
        function pick(req: string, types: int, multiple: int, app: string): void {
            ScreenShare.request({ id: req, types: types || 1, multiple: multiple === 1, app: app });
        }
        function pending(): string { return UiState.screencastRequest ? UiState.screencastRequest.id : ""; }
    }
    IpcHandler {
        target: "keybinds"
        function toggle(): void { UiState.toggle("keybinds"); }
        function open(): void { UiState.closeAll(); UiState.keybinds = true; }
        function close(): void { UiState.keybinds = false; }
    }
    IpcHandler {
        target: "picker"
        function start(): void { ColorPick.start(); }
        function cancel(): void { ColorPick.cancel(); }
    }
    IpcHandler {
        target: "games"
        /// MangoHud in the running game, shown or hidden.
        function hud(): void { GameMode.toggleHud(); }
        /// Game mode by hand (for games the rules do not recognise).
        function toggle(): void { GameMode.forced = !GameMode.forced; }
        function state(): string { return JSON.stringify({ active: GameMode.active, forced: GameMode.forced, game: GameMode.game ? GameMode.game.appId : "", pid: GameMode.registeredPid }); }
    }
    IpcHandler {
        target: "launcher"
        function toggle(): void { UiState.toggle("launcher"); }
        // Mode and query first: the launcher reads them the moment it opens.
        function clipboard(): void { UiState.closeAll(); UiState.launcherMode = "clipboard"; UiState.launcher = true; }
        function emoji(): void { UiState.closeAll(); UiState.launcherMode = "emoji"; UiState.launcher = true; }
        function games(): void { UiState.closeAll(); UiState.launcherMode = "games"; UiState.launcher = true; }
        function open(): void { UiState.closePanel(); UiState.launcher = true; }
        function close(): void { UiState.launcher = false; }
    }
    IpcHandler {
        target: "osd"
        // Keybinds change the value through their own tools (wpctl, brightnessctl)
        // and the OSD follows; these steps go through the shell instead.
        // Directions as words: a "-0.05" argument would be read as a CLI flag.
        function volume(direction: string): void { Audio.step(direction === "down" ? -0.05 : 0.05); UiState.osdRequested("volume"); }
        function mute(): void { Audio.toggleMute(); UiState.osdRequested("volume"); }
        function mic(): void { Audio.toggleMicMute(); UiState.osdRequested("mic"); }
        function brightness(direction: string): void { Power.stepBrightness(direction === "down" ? -0.05 : 0.05); UiState.osdRequested("brightness"); }
        function display(kind: string): void { UiState.osdRequested(kind); }   // "show" is taken by the qs CLI
    }
    IpcHandler {
        target: "switcher"
        function next(): void { UiState.switcherStep(1); }
        function prev(): void { UiState.switcherStep(-1); }
        function commit(): void { UiState.switcherCommit(); }
        function cancel(): void { UiState.switcher = false; }
    }
    IpcHandler {
        target: "capture"
        function open(): void { Capture.open({ kind: "photo" }); }
        function region(): void { Capture.open({ kind: "photo", mode: "area", delay: 0, immediate: true }); }
        function ocr(): void { Capture.open({ kind: "ocr", mode: "area", delay: 0, immediate: true }); }
        function record(): void { if (UiState.recording) Capture.stop(); else Capture.open({ kind: "video" }); }
        function stop(): void { Capture.stop(); }
        function cancel(): void { Capture.cancel(); Capture.cancelCountdown(); }
        /// The last file written, for scripts.
        function last(): string { return Capture.last ? Capture.last.path : ""; }
    }
    IpcHandler {
        target: "widgets"
        function edit(): void { UiState.closeAll(); UiState.widgetsEdit = !UiState.widgetsEdit; }
        function done(): void { UiState.widgetsEdit = false; }
        /// Add a widget (clock, calendar, weather, system, media, notes, shortcuts, battery) to the focused screen.
        function add(type: string): void { UiState.widgetAddRequested(type); }
        /// The stored widgets, for scripts.
        function list(): string { return JSON.stringify(Settings.get("widgets.items", [])); }
    }
    IpcHandler {
        target: "wallpaper"
        /// A file for every screen; with an output name, only that one.
        function set(path: string): void { Wallpaper.set(path, "", null); }
        function setOn(output: string, path: string): void { Wallpaper.set(path, output, null); }
        function picker(): void { UiState.toggle("wallpaperPicker"); }
        function next(): void { Wallpaper.cycle(1); }
        function prev(): void { Wallpaper.cycle(-1); }
        function random(): void { Wallpaper.cycle(0); }
        function get(): string { return Wallpaper.pathFor(Niri.focusedOutput || Quickshell.screens[0].name); }
        function parallax(): void { Settings.set("wallpaper.parallax", !Settings.get("wallpaper.parallax", false)); }
    }
    IpcHandler {
        target: "scheme"
        function toggle(): void { Settings.set("scheme.mode", Colors.dark ? "light" : "dark"); }
        function auto(): void { Settings.set("scheme.mode", "auto"); }
    }
    IpcHandler {
        target: "materials"
        function cycle(): void {
            const order = ["frosted", "glass", "solid"];
            Settings.set("materials.default", order[(order.indexOf(Settings.get("materials.default", "frosted")) + 1) % order.length]);
        }
    }
    IpcHandler {
        target: "notifications"
        function dnd(): void { Notifs.setDoNotDisturb(!Notifs.doNotDisturb); }
        function isDnd(): bool { return Notifs.doNotDisturb; }
        function clear(): void { Notifs.clearHistory(); }
    }
    IpcHandler {
        target: "vitrum"
        function check(): void { VitrumUpdate.check(); }
        function behind(): int { return VitrumUpdate.behind; }
    }
    IpcHandler {
        target: "dock"
        function toggle(): void { Settings.set("dock.enabled", !Settings.get("dock.enabled", true)); }
    }
    IpcHandler {
        target: "media"
        function play(): void { Media.playPause(); }
        function next(): void { Media.next(); }
        function prev(): void { Media.previous(); }
        function art(): string { return Media.artUrl; }
    }
    IpcHandler {
        target: "power"
        function toggle(): void { UiState.toggle("power"); }
    }
    IpcHandler {
        target: "lock"
        function lock(): void { UiState.closeAll(); UiState.locked = true; }
        function isLocked(): bool { return UiState.locked; }
    }
    IpcHandler {
        target: "centre"
        function toggle(): void { UiState.toggle("centre"); }
        function open(): void { UiState.closePanel(); UiState.centre = true; }
        function close(): void { UiState.centre = false; }
    }
    IpcHandler {
        target: "debug"
        function notify(app: string, summary: string, body: string): void { Notifs.inject(app, summary, body); }
        function toasts(): int { return Notifs.popups.length; }
        // Submit a password to the lock screen (tests use a wrong one).
        function lockpass(pw: string): string { if (!lockRef) return "no lock"; lockRef.password = pw; lockRef.submit(); return "submitted"; }
        function polkit(): string { return JSON.stringify({ registered: Polkit.registered, active: Polkit.active, message: Polkit.flow ? Polkit.flow.message : "" }); }
        function polkitcancel(): void { if (Polkit.flow) Polkit.flow.cancelAuthenticationRequest(); }
        /// The lock's look on an ordinary surface, and a refused password without PAM (tests).
        function lockpreview(on: bool): void { if (lockRef) { lockRef.preview = on; if (on) { lockRef.password = ""; lockRef.error = ""; lockRef.failures = 0; lockRef.lockedAt = Date.now(); } } }
        function locktype(text: string): void { if (lockRef) lockRef.password = text; }
        function lockfail(): void { if (lockRef) lockRef.fail("Wrong password"); }
        function lockambient(on: bool): void { if (lockRef) lockRef.ambient = on; }
        function lockleave(): void { if (lockRef) { lockRef.leaving = true; } }
        function idle(): string { return JSON.stringify({ dimmed: Idle.dimmed, awake: Awake.active, media: Awake.media, auto: Awake.automatic }); }
        function hovertitle(on: bool): void { UiState.debugHoverTitle = on; }
        function lockerror(): string { return lockRef ? lockRef.error : ""; }
        function screencastshare(index: int): void { UiState.screencastShareRequested(index); }
        function lockstate(): string { return lockRef ? JSON.stringify({ ambient: lockRef.ambient, quietMs: Date.now() - lockRef.lastInput, ambientSeconds: lockRef.ambientSeconds, password: lockRef.password.length, busy: lockRef.busy, failures: lockRef.failures }) : ""; }
        function dock(): string { return UiState.activeDock ? UiState.activeDock.debugState() : UiState.dockState; }
        /// The bars' state: the open panel's drop, regions (tests).
        /// Open a picture in the screenshot editor (tests).
        function edit(path: string): void { Capture.edit(path); }
        /// What reads as recording the microphone, and as playing (the mixer).
        function audio(): string { return JSON.stringify({ mic: Privacy.micApps, playing: Audio.streams.map(Audio.streamName) }); }
        function bar(): string { UiState.barProbe(); return JSON.stringify(UiState.barDebug); }
        function tiles(): string {
            const o = Niri.focusedOutput;
            return JSON.stringify({ output: o, available: Niri.available, windows: Niri.windowList.length,
                                    tiles: Niri.tilesOn(o, 0), layouts: Niri.windowList.map(w => w.layout) });
        }
        // Type into the open launcher; returns the first result's title.
        function runfirst(): void { UiState.launcherRunFirst(); }
        function query(text: string): string { UiState.launcherQuery = text; return UiState.launcherFirst; }
        /// Select x y w h on the focused screen and take it (the overlay must be open).
        function captureselect(x: int, y: int, w: int, h: int): void { Capture.testSelect(Qt.rect(x, y, w, h), true); }
        function overviewquery(text: string): void { UiState.overviewQueryRequested(text); }
        function captureset(mode: string, kind: string, delay: int): void { Capture.mode = mode; Capture.kind = kind; Capture.delay = delay; }
        /// The same, without taking it (to look at the selection).
        function capturedraw(x: int, y: int, w: int, h: int): void { Capture.testSelect(Qt.rect(x, y, w, h), false); }
        /// Summaries of the newest notifications, newest first.
        function notifs(): string { return JSON.stringify(Notifs.history.slice(0, 5).map(n => n.summary + (n.body ? ": " + n.body : ""))); }
        function state(): string { return JSON.stringify({ panel: UiState.panel, launcher: UiState.launcher, centre: UiState.centre, switcher: UiState.switcher, capture: UiState.capture, frames: UiState.widgetFramesMade, showing: UiState.launcher ? UiState.launcherShowing : "", query: UiState.launcherQuery, recording: UiState.recording, countdown: Capture.countdown, windows: Niri.windowsByRecency().map(w => w.appId) }); }
    }
}
