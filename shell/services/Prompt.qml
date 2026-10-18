pragma Singleton

import QtQuick
import Quickshell

/*
 * Questions the system asks the person, one at a time, as a dialog over the
 * focused screen (modules/dialogs/PromptDialog.qml): a Bluetooth pairing
 * code, a Wi-Fi password.
 *
 *   const t = Prompt.ask({ icon, title, message, code, field, placeholder, okText, cancelText, info }, (ok, value) => …)
 *   Prompt.update(t, { message: … })      change it while it shows
 *   Prompt.dismiss(t)                     take it away without an answer (the caller gave up)
 *
 * field: "" (none), "text", "password" or "number". info: true for a notice
 * with one button (the callback still runs, ok = true). The callback runs
 * once, never for a dismissed question.
 */
Singleton {
    id: root
    property var current: null
    property var _queue: []
    property int _next: 0
    property var _callbacks: ({})

    function ask(req, done) {
        const token = ++_next;
        _callbacks[token] = done || null;
        const q = Object.assign({ token: token, icon: "help", title: "", message: "", code: "", field: "", placeholder: "",
                                  okText: "OK", cancelText: "Cancel", info: false }, req);
        if (current === null) current = q;
        else _queue = _queue.concat([q]);
        return token;
    }
    function update(token, patch) {
        if (current && current.token === token) current = Object.assign({}, current, patch);
        else _queue = _queue.map(q => q.token === token ? Object.assign({}, q, patch) : q);
    }
    function dismiss(token) {
        delete _callbacks[token];
        _queue = _queue.filter(q => q.token !== token);
        if (current && current.token === token) _advance();
    }
    function answer(ok, value) {
        if (!current) return;
        const cb = _callbacks[current.token];
        delete _callbacks[current.token];
        _advance();
        if (cb) cb(ok, value || "");
    }
    function _advance() {
        current = _queue.length ? _queue[0] : null;
        _queue = _queue.slice(1);
    }
}
