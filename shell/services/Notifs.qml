pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../lib/notifs.js" as Lib

/*
 * The freedesktop notification server, plus the history the Notification
 * Centre shows.
 *
 * Two lists, deliberately: `popups` is what is on screen right now and is
 * driven by timeouts, `history` is everything that arrived since login and is
 * only cleared by the user. A notification leaving the screen must not leave
 * the Centre.
 */
Singleton {
    id: root

    property bool doNotDisturb: false
    property var history: []
    property var popups: []
    /// Seconds a toast stays (settings), critical ones stay until dismissed.
    readonly property int timeout: Settings.get("notifications.timeout", 6)

    readonly property int unreadCount: history.filter(n => !n.read).length

    signal arrived(var notification)

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodySupported: true
        imageSupported: true
        inlineReplySupported: true
        persistenceSupported: true

        onNotification: notif => {
            notif.tracked = true;

            const item = Lib.record(notif, new Date());
            // The live object, for invoke/dismiss; never in a record (see lib/notifs.js).
            root._live[notif.id] = notif;
            notif.closed.connect(() => { delete root._live[item.id]; });

            root.history = [item].concat(root.history).slice(0, 200);
            root.arrived(item);

            // Critical notifications ignore Do Not Disturb. That is the whole
            // point of the urgency level.
            const critical = notif.urgency === NotificationUrgency.Critical;
            if (root.doNotDisturb && !critical) return;
            // In a game: held back, told about as one summary afterwards.
            if (GameMode.active && !critical) { root.held++; return; }

            root.popups = [item].concat(root.popups);
            Sounds.play("notification");
        }
    }

    /// Test hook (IPC debug): a notification that did not come over D-Bus.
    // A broken settings file is said out loud, once per breakage.
    Connections {
        target: Settings
        function onErrorChanged() {
            if (Settings.error) root.inject("Settings", "settings.json could not be read",
                "The last good settings stay in use. Your next change keeps the file as settings.json.broken. " + Settings.error);
        }
    }

    /// Notifications that arrived during game mode, not shown yet.
    property int held: 0
    Connections {
        target: GameMode
        function onActiveChanged() {
            if (GameMode.active || root.held === 0) return;
            const n = root.held;
            root.held = 0;
            root.inject("vitrum", n === 1 ? "1 notification while you played" : n + " notifications while you played",
                        "They are in the notification centre.");
        }
    }

    function inject(app, summary, body) { _inject(app, summary, body, false); }
    /// Shown even in Do not disturb and in a game (hardware alerts).
    function injectCritical(app, summary, body) { _inject(app, summary, body, true); }
    function _inject(app, summary, body, critical) {
        const item = Lib.record({ id: -(Date.now() % 1000000000), appName: app, summary: summary, body: body,
                                  urgency: critical ? NotificationUrgency.Critical : NotificationUrgency.Normal }, new Date());
        history = [item].concat(history).slice(0, 200);
        if (!critical && GameMode.active) held++;
        else if (critical || !doNotDisturb) popups = [item].concat(popups);
        arrived(item);
    }

    // ----------------------------------------------------------- actions ---

    function dismissPopup(id) {
        popups = popups.filter(n => n.id !== id);
    }

    /// id → the live Notification, while its sender keeps it open.
    property var _live: ({})
    function _notif(item) { return item ? (_live[item.id] || null) : null; }

    /// A reply typed in the notification, sent to the app (Telegram, KDE Connect).
    function reply(item, text) {
        const n = _notif(item);
        if (n && n.hasInlineReply && text.trim()) n.sendInlineReply(text);
        dismissPopup(item.id);
        markRead(item.id);
    }

    function invoke(item, action) {
        const n = _notif(item);
        if (n) n.actions.filter(a => a.identifier === action).forEach(a => a.invoke());
        dismissPopup(item.id);
        markRead(item.id);
    }

    function activate(item) {
        // Clicking the body is "default" in the spec.
        const n = _notif(item);
        if (n) {
            const def = n.actions.filter(a => a.identifier === "default");
            if (def.length > 0) def[0].invoke();
        }
        dismissPopup(item.id);
        markRead(item.id);
    }

    function close(item) {
        const n = _notif(item);
        if (n) n.dismiss();
        dismissPopup(item.id);
        history = history.filter(n => n.id !== item.id);
    }

    function markRead(id) {
        history = history.map(n => n.id === id ? Object.assign({}, n, { read: true }) : n);
    }

    function markAllRead() {
        if (!history.some(n => !n.read)) return;    // no new array, no model rebuilds
        history = history.map(n => Object.assign({}, n, { read: true }));
    }

    function clearHistory() {
        for (const n of history) { const live = _notif(n); if (live) live.dismiss(); }
        history = [];
        popups = [];
    }

    function setDoNotDisturb(on) {
        doNotDisturb = on;
        if (on) popups = [];
    }

    /// Grouped by application, the way the Notification Centre stacks them.
    function grouped() {
        const groups = {};
        const order = [];
        for (const n of history) {
            if (!groups[n.appName]) { groups[n.appName] = []; order.push(n.appName); }
            groups[n.appName].push(n);
        }
        return order.map(name => ({ appName: name, items: groups[name] }));
    }
}
