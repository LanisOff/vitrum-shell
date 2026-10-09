pragma Singleton

import QtQuick
import Quickshell
import "../lib/screencast.js" as Lib

/*
 * Screen-share requests from vitrum-portal, and their answers. The portal
 * waits for $XDG_RUNTIME_DIR/vitrum-screencast/<request>.json. An app that
 * was told "always share this" gets its answer at once, without the picker
 * (screencast.remember: app id → what to share).
 */
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/vitrum-screencast"
    readonly property var remembered: Settings.get("screencast.remember", {}) || {}

    function _write(id, obj) {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf "%s" "$2" > "$1/$3.tmp" && mv -f "$1/$3.tmp" "$1/$3.json"',
                                 "_", dir, JSON.stringify(obj), id]);
    }

    /// From the portal (IPC): answer from memory, or show the picker. A request
    /// still waiting is answered "cancelled" first, so the portal never hangs.
    function request(req) {
        const old = UiState.screencastRequest;
        if (old) _write(old.id, { ok: false });
        const a = Lib.rememberedAnswer(remembered, req, Quickshell.screens.map(s => ({ name: s.name })), Niri.windowList);
        if (a) {
            _write(req.id, a);
            UiState.screencastRequest = null;
            Notifs.inject(appName(req.app), "Sharing " + Lib.describe(a, Niri.windowList),
                          "As you asked last time. Forget it in Settings → Screenshots & recording.");
            return;
        }
        UiState.closeAll();
        UiState.screencastRequest = req;
    }

    /// The picker's answer; `entry` (Lib.entryFor) to remember it for the app.
    function answer(obj, entry) {
        const req = UiState.screencastRequest;
        if (!req) return;
        _write(req.id, obj);
        if (entry && req.app) remember(req.app, entry);
        UiState.screencastRequest = null;
    }

    function remember(app, entry) {
        const m = Object.assign({}, remembered);
        m[app] = entry;
        Settings.set("screencast.remember", m);
    }
    function forget(app) {
        const m = Object.assign({}, remembered);
        delete m[app];
        Settings.set("screencast.remember", m);
    }

    function appName(id) {
        if (!id) return "An app";
        const a = Apps.forAppId(id);
        return a && a.name ? a.name : id.split(".").pop();
    }
}
