pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "../lib/keyboard.js" as Kb

/*
 * The keyboard's layouts, one interface over two paths: the bar, the OSD, the
 * lock screen, the polkit prompt, per-app memory and Settings read this and
 * never ask which path it is.
 *
 *  - Without the input_method component, niri's own xkb layouts (Niri.qml).
 *  - With it, fcitx5 holds them: keymaps and engines (Mozc, Hangul, Pinyin) from
 *    its profile, which vitrum-theme writes from keyboard.layouts, and niri
 *    keeps one base layout. A change arrives without polling: fcitx5's tray
 *    item (the shell is the StatusNotifierWatcher) gets a new tooltip for every
 *    new input method, and then fcitx5-remote says exactly which.
 *
 * names is in the order the layouts cycle, and the name is the same on both
 * paths ("Russian", "Japanese"), so per-app memory carries across.
 *
 * Held: Qt does not tell the compositor a field is hidden (it sends
 * sensitive_data, never hidden_text or the password purpose, so fcitx5's own
 * password handling does not start), and a password must never meet an
 * engine. So while the lock screen or a polkit prompt is up no engine stays
 * on: a keymap in use stays (a Cyrillic password can be typed, and the keymaps
 * still switch), an engine gives way to the last keymap used and comes back
 * after. Other password fields ask for the same through passwordFocus(). Game
 * mode keeps engines off too, a game that leaves text input on would have its
 * keys composed, and nothing switches there at all.
 */
Singleton {
    id: root

    // ------------------------------------------------------- the interface ---
    /// fcitx5 holds the layouts (the input_method component is on).
    property bool fcitx: false
    readonly property var names: fcitx ? _names : Niri.keyboardLayouts
    readonly property int index: fcitx ? Math.max(0, ims.indexOf(im)) : Niri.keyboardLayoutIndex
    /// The full name: "English (US)", "Russian", "Japanese".
    readonly property string current: names[index] || ""
    /// The label: EN/RU/JP/KR/CN on fcitx5's path, niri's short name on the other.
    readonly property string short: fcitx ? (ims.length ? Kb.fcitxShort(ims[index], current) : "") : Niri.keyboardShort
    readonly property bool available: fcitx ? ims.length > 0 : Niri.available

    function next(forward) {
        if (!fcitx) return Niri.switchLayout(forward);
        if (_passwords) {
            const k = Kb.nextKeymap(ims, im, forward);
            if (k) _set(k);
        } else if (!_game && ims.length > 1) {
            setIndex((index + (forward ? 1 : ims.length - 1)) % ims.length);
        }
    }
    function setIndex(i) {
        if (!fcitx) return Niri.action("switch-layout", String(i));
        if (ims[i]) _set(ims[i]);
    }

    /// next() would do something now.
    readonly property bool switchable: !fcitx ? names.length > 1
        : _passwords ? ims.filter(Kb.isKeymap).length > 1 : !_game && ims.length > 1

    /// Not the user's own choice right now: a hold is on or has just given back
    /// what it took. Memory and the OSD keep out of it.
    readonly property bool held: wantHold || _restoring

    // -------------------------------------------------------- fcitx5's side ---
    /// The input methods in order, and the one that is on ("" before any field had focus).
    property var ims: []
    property string im: ""
    property var rules: []
    readonly property var _names: ims.map(n => Kb.layoutName(rules, Kb.fcitxEntry(n)))

    readonly property string _home: Quickshell.env("HOME")
    readonly property string _config: Quickshell.env("XDG_CONFIG_HOME") || _home + "/.config"
    readonly property string _data: Quickshell.env("XDG_DATA_HOME") || _home + "/.local/share"
    // The Settings app shares this code; only the shell holds and restores.
    readonly property bool inShell: !Quickshell.env("VITRUM_NO_THEME")

    function _set(name) { im = name; Quickshell.execDetached(["fcitx5-remote", "-s", name]); }
    function refresh() {
        if (!fcitx) return;
        if (_ask.running) _again = true; else _ask.running = true;
    }
    property bool _again: false

    onFcitxChanged: refresh()

    Process {
        id: _ask
        command: ["fcitx5-remote", "-n"]
        onExited: if (root._again) { root._again = false; root.refresh(); }
        stdout: StdioCollector {
            onStreamFinished: {
                const s = text.trim();
                if (/^[A-Za-z0-9_-]+$/.test(s)) root.im = s;
            }
        }
    }

    FileView {
        path: root._data + "/vitrum/components.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            // And this session has its environment: another session on the same
            // home (or this one before the next login) still has niri's layouts.
            try {
                root.fcitx = JSON.parse(text()).input_method === true && Quickshell.env("XMODIFIERS") === "@im=fcitx";
            } catch (e) { root.fcitx = false; }
        }
    }
    LazyLoader {
        active: root.fcitx
        Scope {
            FileView {
                path: root._config + "/fcitx5/profile"
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
                onLoaded: root.ims = Kb.parseProfile(text())
            }
            FileView {
                path: "/usr/share/X11/xkb/rules/evdev.lst"
                printErrors: false
                onLoaded: root.rules = Kb.parseRules(text())
            }
            // fcitx5's tray item: its tooltip names the input method.
            Variants {
                model: SystemTray.items.values.filter(i => i.id === "Fcitx")
                Connections {
                    required property var modelData
                    target: modelData
                    Component.onCompleted: root.refresh()
                    function onTooltipTitleChanged() { root.refresh(); }
                    function onIconChanged() { root.refresh(); }
                }
            }
        }
    }

    // ------------------------------------------------------------- holding ---
    /// A password field elsewhere (a prompt, Settings) has the focus.
    function passwordFocus(on) { _field = on; }
    property bool _field: false
    readonly property bool _passwords: fcitx && (_field || (inShell && (UiState.locked || Polkit.active)))
    readonly property bool _game: fcitx && inShell && GameMode.active
    readonly property bool wantHold: _passwords || _game
    // What vitrum-im may do for niri's Alt+Shift: keymaps only, or nothing. A
    // password comes first: a lock over a game must still let the layout change.
    readonly property string _holdMode: _passwords ? "keys" : _game ? "on" : "off"
    on_HoldModeChanged: Quickshell.execDetached(["vitrum-im", "hold", _holdMode])
    property string _saved: ""         // the engine a hold took off
    property string _lastKeymap: ""
    property bool _restoring: false
    onWantHoldChanged: {
        if (wantHold) {
            _restoring = false;
            if (im && !Kb.isKeymap(im)) {
                _saved = im;
                _set(Kb.holdIm(ims, im, _lastKeymap));
            }
        } else if (_saved) {
            _restoring = true;
            _set(_saved);
            _saved = "";
            _settled.restart();
        }
    }
    // Anything that gets past vitrum-im (fcitx5's own hotkey, on a niri without
    // the bind) is put back at once.
    onImChanged: {
        if (Kb.isKeymap(im)) _lastKeymap = im;
        else if (wantHold && im) {
            if (!_saved) _saved = im;
            _set(Kb.holdIm(ims, im, _lastKeymap));
        }
    }
    Timer { id: _settled; interval: 400; onTriggered: root._restoring = false }
}
