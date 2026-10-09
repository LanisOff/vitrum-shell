import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Io
import qs.services
import qs.theme
import "root:/lib/lock.js" as Lib

/*
 * The lock screen — in-session (ext-session-lock): the compositor itself
 * blocks input and output until the shell unlocks.
 *
 * Authentication goes through the system's own PAM stack for `login`, so the
 * same policy as a console login applies. Locks on `vitrum-ipc lock lock`,
 * after lock.idleMinutes of idle, and before sleep (Idle service).
 *
 * While locked a marker file exists; a shell that starts and finds it (the
 * previous one crashed while locked) locks again at once — the compositor
 * keeps the screen locked, and without this nothing would ask for the password.
 *
 * This file is the state (password, PAM, ambient, the unlock hand-off); the
 * look is LockView, one per output.
 */
Scope {
    id: root

    property string password: ""
    // Typing (and a failed attempt, which clears it) is activity too.
    onPasswordChanged: poke()
    property string error: ""
    property bool busy: false
    /// The unlock animation is playing; the session unlocks when it ends.
    property bool leaving: false
    /// Wrong attempts since the last one went through (for the flash).
    property int failures: 0
    property real lockedAt: Date.now()

    // Ambient: after lock.ambientSeconds without input only the clock (and the
    // player) stay. Any key or pointer motion — poke() — brings the rest back.
    property real lastInput: Date.now()
    property bool ambient: false
    readonly property int ambientSeconds: Settings.get("lock.ambientSeconds", 10)
    function poke() {
        lastInput = Date.now();
        if (ambient) ambient = false;
    }
    Timer {
        interval: 500
        running: UiState.locked && !root.leaving
        repeat: true
        onTriggered: root.ambient = Lib.ambientActive(Date.now(), root.lastInput, root.ambientSeconds, root.password.length > 0 || root.busy)
    }

    Connections {
        target: Idle
        function onLockRequested(reason) {
            UiState.locked = true;
            if (lock.secure) Idle.lockShown();
        }
    }
    readonly property string marker: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/vitrum-locked-" + (Quickshell.env("WAYLAND_DISPLAY") || "0")
    Connections {
        target: UiState
        function onLockedChanged() {
            if (UiState.locked) {
                root.password = ""; root.error = ""; root.failures = 0; root.leaving = false;
                root.lockedAt = Date.now(); root.poke();
                Sounds.play("lock");
            }
            Quickshell.execDetached(UiState.locked ? ["touch", root.marker] : ["rm", "-f", root.marker]);
        }
    }
    Process {
        running: true
        command: ["test", "-e", root.marker]
        onExited: code => { if (code === 0) UiState.locked = true; }
    }

    function submit() {
        if (busy || leaving || password.length === 0) return;
        busy = true; error = "";
        pam.start();
    }

    // The count first: the field holds its dots for the shake once it sees it.
    function fail(message) {
        failures++;
        error = message;
        password = "";
    }

    PamContext {
        id: pam
        config: "login"
        onResponseRequiredChanged: if (responseRequired) { respond(root.password); }
        onCompleted: result => {
            root.busy = false;
            if (result === PamResult.Success) {
                root.password = "";
                Sounds.play("unlock");
                // Let the screen dissolve into the desktop, then unlock.
                root.leaving = true;
                unlockLater.restart();
            } else root.fail(result === PamResult.MaxTries ? "Too many attempts" : "Wrong password");
        }
        onError: e => { root.busy = false; root.error = "Authentication is unavailable"; }
    }
    Timer {
        id: unlockLater
        interval: Motion.enabled ? Motion.emphasized : 0
        onTriggered: { UiState.locked = false; root.leaving = false; }
    }

    // Tests: the lock's look on an ordinary surface (niri takes no pictures of
    // a locked session), driven by this same state.
    property bool preview: false
    LazyLoader {
        active: root.preview
        PanelWindow {
            screen: Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "vitrum-lock-preview"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: Colors.bg
            LockView { anchors.fill: parent; lock: root; outputName: Quickshell.screens[0].name }
        }
    }

    WlSessionLock {
        id: lock
        locked: UiState.locked
        // The compositor has the lock up: sleep may go on (Idle holds it till then).
        onSecureChanged: if (secure) Idle.lockShown()

        WlSessionLockSurface {
            id: surface
            color: Colors.bg
            LockView {
                anchors.fill: parent
                lock: root
                outputName: surface.screen ? surface.screen.name : ""
            }
        }
    }
}
