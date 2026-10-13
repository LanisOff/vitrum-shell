pragma Singleton

import QtQuick
import Quickshell
import "../lib/widgets.js" as W

/*
 * The widget editor's session, one for every screen: while it runs the
 * desktops show `draft`, a working copy of widgets.items; every change goes
 * through apply() (undo/redo); Done writes the draft to settings once, Cancel
 * (or Escape) drops it. UiState.widgetsEdit stays the switch everyone uses —
 * the bind, IPC, Settings; turned off by anything but cancel() it saves.
 *
 * Outside the editor the stored list is what shows, and content kept in a
 * widget's options (a note's text, the to-do items) is saved straight away.
 */
Singleton {
    id: root

    readonly property bool active: UiState.widgetsEdit
    /// The stored widgets, with stable ids for entries written by hand without one.
    readonly property var stored: { let n = 0; return W.sanitize(Settings.get("widgets.items", []), () => "auto" + (n++)); }
    property var draft: []
    readonly property var all: active ? draft : stored
    function items(output) { return W.forOutput(all, output); }
    /// Custom widgets' entries by type (script:<id>, qml:<dir>), for W.meta.
    readonly property var custom: CustomWidgets.entries

    property var history: ({ undo: [], redo: [] })
    readonly property bool canUndo: history.undo.length > 0
    readonly property bool canRedo: history.redo.length > 0

    property var selection: []
    readonly property string selectedId: selection.length === 1 ? selection[0] : ""
    /// gallery | selected | custom
    property string tab: "gallery"
    /// A gallery card being dragged onto a stage: its type.
    property string dragType: ""

    property bool _cancelling: false
    onActiveChanged: {
        if (active) {
            draft = stored;
            history = { undo: [], redo: [] };
            selection = [];
            tab = "gallery";
        } else if (!_cancelling) _save();
    }
    function done() { UiState.widgetsEdit = false; }
    function cancel() { _cancelling = true; UiState.widgetsEdit = false; _cancelling = false; selection = []; }
    function _save() {
        if (JSON.stringify(draft) !== JSON.stringify(stored)) Settings.set("widgets.items", draft);
        selection = [];
    }

    function newId() { return Date.now().toString(36) + Math.floor(Math.random() * 1e6).toString(36); }
    /// The size of an output, in the logical pixels items are kept in.
    function bounds(output) {
        const s = Quickshell.screens.find(x => x.name === output) || Quickshell.screens[0];
        return s ? { w: s.width, h: s.height } : { w: 1920, h: 1080 };
    }
    readonly property int grid: 8

    // ------------------------------------------------------------ edits ---
    function apply(list) {
        if (JSON.stringify(list) === JSON.stringify(draft)) return;
        history = W.historyPush(history, draft).h;
        draft = list;
    }
    function undo() {
        const r = W.historyUndo(history, draft);
        if (r.value === null) return;
        history = r.h; draft = r.value; _keepSelection();
    }
    function redo() {
        const r = W.historyRedo(history, draft);
        if (r.value === null) return;
        history = r.h; draft = r.value; _keepSelection();
    }
    function _keepSelection() { selection = selection.filter(id => draft.some(i => i.id === id)); }

    function patch(id, p) { apply(W.update(draft, id, p)); }
    /// Several widgets at once (a group dragged together): { id: patch }.
    function patchMany(patches) {
        apply(draft.map(i => {
            if (!patches[i.id]) return i;
            const n = Object.assign({}, i);
            for (const k in patches[i.id]) n[k] = patches[i.id][k];
            return n;
        }));
    }
    /// A widget's options: in the editor an edit like any other; outside it
    /// (a note typed into, a to-do ticked) saved at once.
    function setOptions(id, options) {
        if (active) { patch(id, { options: options }); return; }
        Settings.set("widgets.items", W.update(stored, id, { options: options }));
    }
    function addType(type, output, top) {
        const id = newId();
        apply(W.add(draft, type, output, bounds(output), grid, top, () => id, custom));
        selection = [id];
        return id;
    }
    /// Dropped from the gallery at (x, y) on `output`, centred on the point.
    function addAt(type, output, x, y) {
        const id = addType(type, output, 0);
        const it = draft.find(i => i.id === id);
        const r = W.place({ x: x - it.w / 2, y: y - it.h / 2, w: it.w, h: it.h }, bounds(output), grid, { w: 120, h: 80 });
        draft = W.update(draft, id, { x: r.x, y: r.y });     // the same edit as the add: one undo
        return id;
    }
    function removeSelected() {
        if (!selection.length) return;
        apply(draft.filter(i => selection.indexOf(i.id) < 0));
        selection = [];
    }
    function remove(id) { apply(draft.filter(i => i.id !== id)); selection = selection.filter(x => x !== id); }
    function duplicateSelected() {
        let list = draft;
        const made = [];
        for (const id of selection) {
            const it = list.find(i => i.id === id);
            if (!it) continue;
            const nid = newId() + made.length;
            list = W.duplicate(list, id, () => nid, bounds(it.output), grid);
            made.push(nid);
        }
        apply(list);
        if (made.length) selection = made;
    }
    function setPreset(id, preset) {
        const it = draft.find(i => i.id === id);
        if (it) patch(id, W.presetRect(it, preset, bounds(it.output), grid));
    }
    function alignSelected(how) { apply(W.alignItems(draft, selection, how)); }
    function distributeSelected(axis) { apply(W.distribute(draft, selection, axis)); }
    function moveToOutput(id, output, pos) { apply(W.moveToOutput(draft, id, output, pos, bounds(output), grid)); }

    // -------------------------------------------------------- selection ---
    function select(id, additive) {
        if (additive) selection = selection.indexOf(id) >= 0 ? selection.filter(x => x !== id) : selection.concat([id]);
        else selection = [id];
        if (selection.length) tab = "selected";
    }
    function selectOnly(ids) { selection = ids; if (ids.length) tab = "selected"; }
    function clearSelection() { selection = []; }
    function isSelected(id) { return selection.indexOf(id) >= 0; }
}
