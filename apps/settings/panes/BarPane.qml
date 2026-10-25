import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components
import qs.common
import Quickshell.Io
import "../lib/bar.js" as BarLib

/*
 * The bar: where it sits and its primary screen, then the editor. Pick all
 * screens (the shared layout, bar.layout) or one screen with its own layout
 * (bar.screens.<name>.layout); drag modules about a live bar; click one for
 * its options (bar.minimap, bar.modules.*, the clock's and lyrics' keys:
 * lib/bar.js's catalog names them).
 *
 * The editor's parts are inline components: a pane is loaded by URL, so
 * Quickshell never scans its imports and a directory of its own (panes/bar)
 * is not there for it.
 */
Page {
    id: page
    title: "Bar"
    subtitle: "Islands of modules on the left, in the centre and on the right. Drag them about the bar, or click one for its options."
    Section {
        SettingChoice { key: "bar.position"; names: ({ top: "Top", bottom: "Bottom" }) }
        SettingChoice {
            key: "bar.primary"; label: "Primary screen"; hint: "Where the tray lives. Automatic: the top-left screen of the layout."
            values: [""].concat(Quickshell.screens.map(s => s.name)); names: ({ "": "Automatic" })
            divider: false
        }
    }
    Column {
        width: parent.width
        spacing: Tokens.gap * 1.5
        Label { text: "Layout"; role: "dim"; size: Tokens.textSmall; font.weight: Font.DemiBold; leftPadding: Tokens.padding * 0.5 }
        ScreenPicker { id: screens; width: parent.width }
        BarEditor { width: parent.width; screen: screens.screen; flick: page }
    }
    // Tests: qs ipc call barpane list / screen <name> / own true|false.
    IpcHandler {
        target: "barpane"
        function screen(name: string): void { screens.screen = name; }
        function own(on: bool): void { screens.setOwn(on); }
        function list(): string { return JSON.stringify(screens.names); }
    }

    /*
     * The bar editor: a live bar (left, centre and right, and the activities
     * strip under it), a line that says what a drag or a click will do, the
     * selected module's options, and the palette of every module.
     *
     * How drag and drop holds together:
     *   - One MouseArea under everything takes the pointer. Chips and palette
     *     cards have no mouse handling: it hit-tests them by geometry. So the
     *     drag (what is lifted, where it would land) lives here, never in a
     *     delegate a model change could destroy.
     *   - While a drag runs, the layout is frozen: nothing is saved and nothing
     *     is rebuilt (a settings change from elsewhere waits until the drop). The
     *     lifted chip stays as a faded hole, a ghost follows the pointer, and a
     *     caret (into an island) or a lit gap (a new island) shows the target.
     *   - On the drop, the pure functions in lib/bar.js make the new layout and
     *     it is saved once. Positions are read against the layout as shown, which
     *     is what the hit test sees.
     *   - The selection is a module id, never an index: it survives every change.
     *
     * screen ""  edits bar.layout; a screen's name edits bar.screens.<name>.layout
     * while that screen has its own layout (otherwise it shows the shared one,
     * read-only). flick: the page, scrolled while a drag nears its edges.
     */
    component BarEditor: Item {
        id: ed
        /// Itself, for the parts' `ed` (a plain `ed: ed` there could read their own property).
        readonly property Item editorItem: ed
        property string screen: ""
        property Flickable flick: null

        // ---------------------------------------------------------- the layout ---
        readonly property bool own: screen !== "" && Settings.get("bar.screens." + screen + ".own", false) === true
        readonly property bool editable: screen === "" || own
        readonly property string saveKey: screen !== "" && own ? "bar.screens." + screen + ".layout" : "bar.layout"
        readonly property var sourceLayout: BarLib.normalize(BarLib.layoutFor(Settings.get("bar", {}), screen))
        /// What the editor shows: the source, adopted only when it really changed
        /// (any settings write gives a new object) and never during a drag.
        property var layout: ({ left: [], center: [], activities: [], right: [] })
        property string _json: ""
        function _sync() {
            if (dragging) return;
            const j = JSON.stringify(sourceLayout);
            if (j === _json) return;
            _json = j;
            layout = sourceLayout;
            if (selectedId && used.indexOf(selectedId) < 0 && !selectedFromPalette) selectedId = "";
        }
        onSourceLayoutChanged: _sync()
        onScreenChanged: { selectedId = ""; confirmReset = false; _json = ""; _sync(); }
        Component.onCompleted: _sync()

        readonly property var catalog: BarLib.catalog()
        readonly property var _byId: { const m = {}; for (const e of catalog) m[e.id] = e; return m; }
        function infoOf(id) { return _byId[id] || { id: id, name: id, icon: "help", description: "", options: [] }; }
        readonly property var used: BarLib.usedModules(layout)

        readonly property var sideNames: ({ left: "Left", center: "Centre", activities: "Activities", right: "Right" })
        function find(id) {
            for (const side of ["left", "center", "activities", "right"]) {
                const isl = layout[side] || [];
                for (let i = 0; i < isl.length; i++) {
                    const k = isl[i].indexOf(id);
                    if (k >= 0) return { side: side, island: i, index: k };
                }
            }
            return null;
        }
        function whereText(id) {
            const at = find(id);
            if (!at) return "";
            const n = layout[at.side].length;
            return sideNames[at.side] + (n > 1 ? ", island " + (at.island + 1) + " of " + n : "");
        }

        /// Save a new layout: once, and only when it differs.
        function commit(next) {
            if (Settings.error) return;
            const n = BarLib.normalize(next);
            const j = JSON.stringify(n);
            if (j === _json) return;
            _json = j;
            layout = n;
            Settings.set(saveKey, n);
        }
        function resetLayout() { commit(BarLib.defaultLayout()); confirmReset = false; }
        property bool confirmReset: false

        // ----------------------------------------------------------- selection ---
        property string selectedId: ""
        /// The selection came from a palette card of a module not in the bar.
        property bool selectedFromPalette: false
        function select(id) {
            selectedFromPalette = false;
            selectedId = selectedId === id ? "" : id;
        }
        function removeSelected() {
            const at = find(selectedId);
            if (!at || !editable) return;
            commit(BarLib.removeModule(layout, at));
            selectedId = "";
        }

        // ------------------------------------------------------------ geometry ---
        readonly property int inset: Math.round(3 * Tokens.islandHeight / 30)
        readonly property int chipH: Tokens.islandHeight - 2 * inset
        readonly property int chipRadius: Math.max(2, Tokens.islandRadius - inset)
        readonly property int chipText: Tokens.textSmall
        readonly property int chipSpacing: 2
        readonly property int chipPad: Math.round(Tokens.gap * 0.75)
        readonly property real restSpacing: Tokens.gap
        readonly property real dragSpacing: Tokens.gap * 3
        /// Between islands: wider while dragging, so the gaps (new islands) are easy to hit.
        property real islandSpacing: dragging ? dragSpacing : restSpacing
        Behavior on islandSpacing { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
        readonly property real placeholderW: Tokens.islandHeight * 2.6
        readonly property real captionW: Math.max(actCap.implicitWidth, actSub.implicitWidth) + Tokens.gap * 2

        FontMetrics { id: fm; font.family: Tokens.fontText; font.pixelSize: ed.chipText }
        function _chipW(id, small) {
            if (small) return chipH + 2;
            fm.height;   // a dependency: the font
            return Math.ceil(Tokens.iconSize + 5 + fm.advanceWidth(infoOf(id).name) + 2 * chipPad);
        }
        function compactFor(side) { return side === "activities" ? actCompact : mainCompact; }
        function chipWidth(id, side) { return _chipW(id, compactFor(side)); }
        function _islandW(mods, small) {
            let w = 2 * inset + Math.max(0, mods.length - 1) * chipSpacing;
            for (const m of mods) w += _chipW(m, small);
            return w;
        }
        function islandWidth(mods, side) { return _islandW(mods || [], compactFor(side)); }
        function _zoneW(islands, small, sp) {
            if (!islands || !islands.length) return placeholderW;
            let w = (islands.length - 1) * sp;
            for (const i of islands) w += _islandW(i, small);
            return w;
        }
        function zoneWidth(islands, side) { return _zoneW(islands, compactFor(side), islandSpacing); }
        // What each strip needs (with the drag's spacing, so a drag never flips the mode).
        function _mainNeed(small) {
            const L = _zoneW(layout.left, small, dragSpacing), C = _zoneW(layout.center, small, dragSpacing), R = _zoneW(layout.right, small, dragSpacing);
            return L + C + R + 4 * dragSpacing;
        }
        function _actNeed(small) { return _zoneW(layout.activities, small, dragSpacing) + 2 * dragSpacing; }
        readonly property real stripW: Math.max(100, width - Tokens.padding * 2)
        readonly property real actW: Math.max(60, stripW - captionW)
        /// Names on the chips while they fit, else icons alone; past that the strips scale down.
        readonly property bool mainCompact: _mainNeed(false) > stripW
        readonly property bool actCompact: _actNeed(false) > actW
        readonly property real mainScale: Math.min(1, stripW / _mainNeed(mainCompact))
        readonly property real actScale: Math.min(1, actW / _actNeed(actCompact))

        function zoneItem(side) { return side === "left" ? zLeft : side === "center" ? zCenter : side === "right" ? zRight : zAct; }
        function rectOf(item) { return item.mapToItem(ed, 0, 0, item.width, item.height); }
        function _inside(r, x, y) { return x >= r.x && x <= r.x + r.width && y >= r.y && y <= r.y + r.height; }

        /// What is under the pointer: { kind: "bar"|"palette", id, rect } or null.
        function hitItem(x, y) {
            for (const side of ["left", "center", "activities", "right"]) {
                const z = zoneItem(side);
                for (let i = 0; i < z.count; i++) {
                    const isl = z.islandAt(i);
                    if (!isl) continue;
                    for (let j = 0; j < isl.count; j++) {
                        const c = isl.chipAt(j);
                        if (!c) continue;
                        const r = rectOf(c);
                        if (_inside(r, x, y)) return { kind: "bar", id: c.moduleId, rect: r };
                    }
                }
            }
            for (let i = 0; i < paletteRep.count; i++) {
                const card = paletteRep.itemAt(i);
                if (!card) continue;
                const r = rectOf(card);
                if (_inside(r, x, y)) return { kind: "palette", id: card.moduleId, rect: r };
            }
            return null;
        }

        // ---------------------------------------------------------------- drag ---
        property var press: null          // { kind, id, x, y, ox, oy }
        property bool dragging: false
        property string dragKind: ""      // "bar" | "palette"
        property string dragId: ""
        property real dragX: 0            // the pointer, in the editor
        property real dragY: 0
        property point _flickPoint: Qt.point(0, 0)
        /// Where it would land: { kind: "island", side, island, index } |
        /// { kind: "gap", side, gap } | { kind: "remove" } | null — plus `ind`,
        /// the indicator's rect in the editor.
        property var dropTarget: null
        property string hoverKey: ""

        function beginDrag() {
            dragKind = press.kind;
            dragId = press.id;
            dragging = true;
            hoverKey = "";
        }
        function pointerAt(x, y) {
            dragX = x; dragY = y;
            if (flick) _flickPoint = ed.mapToItem(flick, x, y);
            dropTarget = resolve(x, y);
        }
        function endDrag() {
            dragging = false;
            dropTarget = null;
            press = null;
            dragKind = "";
            dragId = "";
            Qt.callLater(_sync);
        }
        function drop() {
            const t = dropTarget, kind = dragKind, id = dragId;
            endDrag();
            if (!t || !editable) return;
            if (kind === "bar") {
                const from = find(id);
                if (!from) return;
                commit(t.kind === "remove" ? BarLib.removeModule(layout, from) : BarLib.moveModule(layout, from, _to(t)));
                if (t.kind === "remove" && selectedId === id) selectedId = "";
            } else if (t.kind !== "remove") {
                commit(BarLib.insertModule(layout, id, _to(t)));
                selectedFromPalette = false;
                selectedId = id;
            }
        }
        function _to(t) { return t.kind === "gap" ? { side: t.side, gap: t.gap } : { side: t.side, island: t.island, index: t.index }; }

        /// The target under (x, y). Over an island: a slot between its chips.
        /// Anywhere else on the bar: the nearest gap of the nearest side (a new
        /// island). Off the bar: remove (a bar module) or nothing (from the palette).
        function resolve(x, y) {
            const pr = rectOf(plate), m = 6;
            if (x < pr.x - m || x > pr.x + pr.width + m || y < pr.y - m || y > pr.y + pr.height + m)
                return dragKind === "bar" ? { kind: "remove" } : null;
            const sr = rectOf(strip), ar = rectOf(actStrip);
            const split = (sr.y + sr.height + ar.y) / 2;
            const sides = y < split ? ["left", "center", "right"] : ["activities"];
            let best = null, bestD = Infinity;
            function gapCand(side, gap, r) {
                const cx = r.x + r.width / 2, d = Math.abs(x - cx);
                if (d < bestD) { bestD = d; best = { kind: "gap", side: side, gap: gap, ind: r }; }
            }
            for (const side of sides) {
                const z = zoneItem(side), n = z.islands.length;
                const zr = rectOf(z);
                if (n === 0 || z.count === 0) { gapCand(side, 0, zr); continue; }
                const sc = side === "activities" ? actScale : mainScale;
                const sp = islandSpacing * sc, h = zr.height;
                const rs = [];
                for (let i = 0; i < z.count; i++) rs.push(rectOf(z.islandAt(i)));
                for (let i = 0; i < rs.length; i++) {
                    const r = rs[i];
                    if (x >= r.x && x <= r.x + r.width) return _islandTarget(side, i, z.islandAt(i), r, x);
                }
                // The gaps: before the first island, between, after the last.
                gapCand(side, 0, Qt.rect(rs[0].x - sp, zr.y, sp, h));
                for (let g = 1; g < rs.length; g++)
                    gapCand(side, g, Qt.rect(rs[g - 1].x + rs[g - 1].width, zr.y, rs[g].x - rs[g - 1].x - rs[g - 1].width, h));
                const last = rs[rs.length - 1];
                gapCand(side, rs.length, Qt.rect(last.x + last.width, zr.y, sp, h));
            }
            return best;
        }
        function _islandTarget(side, i, isl, r, x) {
            let idx = 0;
            const cs = [];
            for (let j = 0; j < isl.count; j++) {
                const c = rectOf(isl.chipAt(j));
                cs.push(c);
                if (x > c.x + c.width / 2) idx = j + 1;
            }
            let cx;
            if (!cs.length) cx = r.x + r.width / 2;
            else if (idx === 0) cx = cs[0].x - 1;
            else if (idx === cs.length) cx = cs[cs.length - 1].x + cs[cs.length - 1].width + 1;
            else cx = (cs[idx - 1].x + cs[idx - 1].width + cs[idx].x) / 2;
            const ch = r.height - 8 * (side === "activities" ? actScale : mainScale);
            return { kind: "island", side: side, island: i, index: idx, ind: Qt.rect(cx - 1, r.y + (r.height - ch) / 2, 2, ch) };
        }

        // While dragging: scroll the page near its edges, and keep the target
        // honest while the gaps open up under a still pointer.
        Timer {
            interval: 16
            repeat: true
            running: ed.dragging
            onTriggered: {
                if (ed.flick) {
                    const f = ed.flick, edge = Tokens.islandHeight * 1.5, p = ed._flickPoint;
                    let dy = 0;
                    if (p.y < edge) dy = -Math.ceil((edge - p.y) / 4);
                    else if (p.y > f.height - edge) dy = Math.ceil((p.y - (f.height - edge)) / 4);
                    const maxY = Math.max(0, f.contentHeight - f.height);
                    const ny = Math.max(0, Math.min(maxY, f.contentY + dy));
                    if (ny !== f.contentY) {
                        f.contentY = ny;
                        const q = f.mapToItem(ed, p.x, p.y);
                        ed.dragX = q.x; ed.dragY = q.y;
                    }
                }
                ed.dropTarget = ed.resolve(ed.dragX, ed.dragY);
            }
        }

        // ------------------------------------------------------------ keyboard ---
        // The selected module: ← → move it (across islands, and between left,
        // centre and right at their ends), Delete removes it, Escape lets go.
        activeFocusOnTab: true
        Keys.onPressed: e => { if (keyPress(e.key)) e.accepted = true; }
        /// → whether the key was used.
        function keyPress(key) {
            if (!selectedId) return false;
            if (key === Qt.Key_Escape) { selectedId = ""; return true; }
            const at = find(selectedId);
            if (!at || !editable || dragging) return false;
            if (key === Qt.Key_Delete || key === Qt.Key_Backspace) { removeSelected(); return true; }
            if (key !== Qt.Key_Left && key !== Qt.Key_Right) return false;
            const isl = layout[at.side], left = key === Qt.Key_Left;
            let to = null;
            if (left) {
                if (at.index > 0) to = { side: at.side, island: at.island, index: at.index - 1 };
                else if (at.island > 0) to = { side: at.side, island: at.island - 1, index: isl[at.island - 1].length };
            } else {
                if (at.index < isl[at.island].length - 1) to = { side: at.side, island: at.island, index: at.index + 2 };
                else if (at.island < isl.length - 1) to = { side: at.side, island: at.island + 1, index: 0 };
            }
            if (!to) {
                // Off the end of a side: into the next of left, centre, right.
                const order = ["left", "center", "right"], k = order.indexOf(at.side);
                const next = k < 0 ? null : order[k + (left ? -1 : 1)];
                if (next) {
                    const n = layout[next].length;
                    to = !n ? { side: next, gap: 0 }
                       : left ? { side: next, island: n - 1, index: layout[next][n - 1].length }
                       : { side: next, island: 0, index: 0 };
                }
            }
            if (to) commit(BarLib.moveModule(layout, at, to));
            return true;
        }

        // ---------------------------------------------------------------- tests ---
        // qs ipc call bareditor …: the drag by geometry, through the same hit
        // test, target and drop as the pointer (the live tests cannot drag).
        function _rectFor(key) {
            const bar = key.indexOf("pal:") !== 0, id = bar ? key : key.slice(4);
            for (const side of ["left", "center", "activities", "right"]) {
                const z = zoneItem(side);
                for (let i = 0; bar && i < z.count; i++) {
                    const isl = z.islandAt(i);
                    for (let j = 0; isl && j < isl.count; j++) if (isl.chipAt(j).moduleId === id) return rectOf(isl.chipAt(j));
                }
            }
            for (let i = 0; !bar && i < paletteRep.count; i++) if (paletteRep.itemAt(i).moduleId === id) return rectOf(paletteRep.itemAt(i));
            return null;
        }
        IpcHandler {
            target: "bareditor"
            function state(): string {
                return JSON.stringify({ layout: ed.layout, selected: ed.selectedId, mainCompact: ed.mainCompact, actCompact: ed.actCompact, mainScale: ed.mainScale,
                                        actScale: ed.actScale, editable: ed.editable, saveKey: ed.saveKey });
            }
            /// Lift `from` (a module id, or pal:<id> from the palette) and hold it
            /// over `over` (a module id, plus dx px from its centre) or "out" (off
            /// the bar); drop when `drop`. → the target it showed.
            function drag(from: string, over: string, dx: int, drop: bool): string {
                const a = ed._rectFor(from);
                if (!a) return "no " + from;
                let x, y;
                if (over === "out") { const pr = ed.rectOf(plate); x = pr.x + pr.width / 2; y = pr.y + pr.height + 40; }
                else if (over.indexOf("gap:") === 0) {
                    // gap:<side>:<n> — the middle of that gap.
                    const p = over.split(":"), z = ed.zoneItem(p[1]), n = Number(p[2]), zr = ed.rectOf(z);
                    y = zr.y + zr.height / 2;
                    if (!z.count) x = zr.x + zr.width / 2;
                    else {
                        const f = ed.rectOf(z.islandAt(0)), l = ed.rectOf(z.islandAt(z.count - 1)), sp = 3;
                        x = n <= 0 ? f.x - sp : n >= z.count ? l.x + l.width + sp
                          : (ed.rectOf(z.islandAt(n - 1)).x + ed.rectOf(z.islandAt(n - 1)).width + ed.rectOf(z.islandAt(n)).x) / 2;
                    }
                } else {
                    const b = ed._rectFor(over);
                    if (!b) return "no " + over;
                    x = b.x + b.width / 2 + dx; y = b.y + b.height / 2;
                }
                ed.press = { kind: from.indexOf("pal:") === 0 ? "palette" : "bar", id: from.replace("pal:", ""), x: a.x, y: a.y, ox: a.width / 2, oy: a.height / 2 };
                ed.beginDrag();
                ed.pointerAt(x, y);
                const t = JSON.stringify(ed.dropTarget);
                if (drop) ed.drop();
                return t;
            }
            function cancel(): void { ed.endDrag(); }
            /// The editor as an image (the window may be off the screenshots).
            function shot(path: string): void { ed.grabToImage(r => r.saveToFile(path)); }
            function select(id: string): void { ed.selectedFromPalette = false; ed.selectedId = id; }
        /// A click without a drag: a module id, or pal:<id> on the palette.
        function click(k: string): void { if (k.indexOf("pal:") === 0) ed.paletteClick(k.slice(4)); else ed.select(k); }
            function remove(): void { ed.removeSelected(); }
        /// left, right, delete, escape — as the keys.
        function key(k: string): void { ed.keyPress(({ left: Qt.Key_Left, right: Qt.Key_Right, delete: Qt.Key_Delete, escape: Qt.Key_Escape })[k]); }
            function reset(): void { ed.resetLayout(); }
        }

        // ------------------------------------------------------------- pointer ---
        implicitHeight: col.implicitHeight
        MouseArea {
            id: pointer
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: ed.dragging ? Qt.ClosedHandCursor : ed.hoverKey ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: m => {
                const h = ed.hitItem(m.x, m.y);
                if (!h) { m.accepted = false; return; }
                ed.forceActiveFocus();
                ed.press = { kind: h.kind, id: h.id, x: m.x, y: m.y, ox: m.x - h.rect.x, oy: m.y - h.rect.y };
            }
            onPositionChanged: m => {
                if (!pressed || !ed.press) {
                    const h = ed.hitItem(m.x, m.y);
                    ed.hoverKey = h ? h.kind.slice(0, 3) + ":" + h.id : "";
                    return;
                }
                if (!ed.dragging) {
                    if (!ed.editable || Math.hypot(m.x - ed.press.x, m.y - ed.press.y) < 6) return;
                    ed.beginDrag();
                }
                ed.pointerAt(m.x, m.y);
            }
            onReleased: m => {
                if (ed.dragging) { ed.drop(); return; }
                const p = ed.press;
                ed.press = null;
                if (!p) return;
                if (p.kind === "bar") ed.select(p.id);
                else ed.paletteClick(p.id);
            }
            onCanceled: { if (ed.dragging) ed.endDrag(); ed.press = null; }
            onExited: if (!pressed) ed.hoverKey = ""
        }

        /// A click on a palette card: a module in the bar is selected there; one
        /// that is not goes to the end of the right side, as an island of its own.
        function paletteClick(id) {
            if (used.indexOf(id) >= 0) { select(id); return; }
            if (!editable) { selectedFromPalette = true; selectedId = id; return; }
            commit(BarLib.insertModule(layout, id, { side: "right", gap: layout.right.length }));
            selectedFromPalette = false;
            selectedId = id;
        }

        // -------------------------------------------------------------- the view ---
        Column {
            id: col
            width: parent.width
            spacing: Tokens.gap * 1.5

            // A piece of screen with the bar on it, and the activities under it.
            Item {
                id: plate
                width: parent.width
                height: actRow.y + actRow.height + Tokens.padding
                Surface {
                    anchors.fill: parent
                    group: "panels"; level: 1
                    radius: Tokens.radiusInner
                }
                // A desktop's light falling from the top, so the bar sits on something.
                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.radiusInner
                    gradient: Gradient {
                        GradientStop { position: 0; color: Colors.alpha(Colors.text, 0.05) }
                        GradientStop { position: 0.7; color: Colors.alpha(Colors.text, 0.01) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }
                Item {
                    id: strip
                    x: Tokens.padding; y: Tokens.padding
                    width: ed.stripW
                    height: Tokens.islandHeight * ed.mainScale
                    opacity: ed.editable ? 1 : 0.6
                    Item {
                        id: stripInner
                        width: strip.width / ed.mainScale
                        height: Tokens.islandHeight
                        scale: ed.mainScale
                        transformOrigin: Item.TopLeft
                        ZoneRow { id: zLeft; ed: editorItem; side: "left"; caption: "Left"; x: ed.islandSpacing }
                        // Centred, unless a long side pushes it over (the bar does the same).
                        ZoneRow {
                            id: zCenter; ed: editorItem; side: "center"; caption: "Centre"
                            x: Math.round(Math.max(zLeft.x + zLeft.width + ed.islandSpacing,
                                                   Math.min((stripInner.width - width) / 2, zRight.x - ed.islandSpacing - width)))
                        }
                        ZoneRow { id: zRight; ed: editorItem; side: "right"; caption: "Right"; x: stripInner.width - width - ed.islandSpacing }
                    }
                }
                Rectangle {
                    id: rule
                    x: Tokens.padding; width: ed.stripW; height: 1
                    y: strip.y + strip.height + Tokens.gap * 1.5
                    color: Colors.alpha(Colors.text, 0.07)
                }
                Item {
                    id: actRow
                    x: Tokens.padding
                    y: rule.y + Tokens.gap * 1.5
                    width: ed.stripW
                    height: Math.max(capCol.implicitHeight, actStrip.height)
                    opacity: ed.editable ? 1 : 0.6
                    Column {
                        id: capCol
                        width: ed.captionW
                        anchors.verticalCenter: parent.verticalCenter
                        Label { id: actCap; text: "Activities"; size: Tokens.textSmall; font.weight: Font.DemiBold }
                        Label { id: actSub; text: "Right of the centre,\nonly while they run"; role: "dim"; size: Tokens.textSmall - 1; elide: Text.ElideNone }
                    }
                    Item {
                        id: actStrip
                        x: ed.captionW
                        anchors.verticalCenter: parent.verticalCenter
                        width: ed.actW
                        height: Tokens.islandHeight * ed.actScale
                        Item {
                            width: actStrip.width / ed.actScale
                            height: Tokens.islandHeight
                            scale: ed.actScale
                            transformOrigin: Item.TopLeft
                            ZoneRow { id: zAct; ed: editorItem; side: "activities"; caption: "None"; x: ed.islandSpacing }
                        }
                    }
                }
            }

            // What a drag or a click does now, and Reset.
            Item {
                width: parent.width
                height: Math.max(hint.implicitHeight, resetRow.height)
                Label {
                    id: hint
                    anchors { left: parent.left; leftMargin: Tokens.padding * 0.5; right: resetRow.left; rightMargin: Tokens.gap; verticalCenter: parent.verticalCenter }
                    role: ed.dropTarget && ed.dropTarget.kind === "remove" ? "danger" : "dim"
                    size: Tokens.textSmall
                    wrapMode: Text.WordWrap; elide: Text.ElideNone
                    text: {
                        const t = ed.dropTarget, name = ed.dragId ? ed.infoOf(ed.dragId).name : "";
                        if (ed.dragging) {
                            if (!t) return "Drop it on the bar to add it.";
                            if (t.kind === "remove") return "Let go to remove " + name + " from the bar.";
                            if (t.kind === "gap") return "Let go to make " + name + " a new island (" + ed.sideNames[t.side].toLowerCase() + ").";
                            return "Let go to put " + name + " into this island.";
                        }
                        if (!ed.editable) return "This screen uses the shared layout. Switch on Own layout to change its bar alone.";
                        if (ed.hoverKey) {
                            const e = ed.infoOf(ed.hoverKey.slice(4));
                            return e.name + ": " + e.description;
                        }
                        return "Drag a module to move it, into a gap for an island of its own, or off the bar to remove it. Click one for its options; ← → move it, Delete removes it.";
                    }
                }
                Row {
                    id: resetRow
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: Tokens.gap
                    Label {
                        visible: ed.confirmReset
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Put back the default layout?"
                        size: Tokens.textSmall + 1
                    }
                    GlassButton {
                        visible: ed.confirmReset
                        label: "Cancel"; labelSize: Tokens.textSmall + 1
                        onClicked: ed.confirmReset = false
                    }
                    GlassButton {
                        visible: ed.confirmReset
                        label: "Reset"; labelSize: Tokens.textSmall + 1
                        primary: true; danger: true
                        onClicked: ed.resetLayout()
                    }
                    GlassButton {
                        visible: !ed.confirmReset
                        enabled: ed.editable
                        icon: "restart"; label: "Reset to default"; labelSize: Tokens.textSmall + 1
                        onClicked: ed.confirmReset = true
                    }
                }
            }

            ModuleOptions {
                width: parent.width
                visible: ed.selectedId !== ""
                entry: ed.selectedId ? ed.infoOf(ed.selectedId) : null
                where: { ed.layout; return ed.selectedId ? ed.whereText(ed.selectedId) : ""; }
                canRemove: ed.editable
                onRemove: ed.removeSelected()
                onClose: ed.selectedId = ""
            }

            Label { text: "Modules"; role: "dim"; size: Tokens.textSmall; font.weight: Font.DemiBold; leftPadding: Tokens.padding * 0.5 }
            Flow {
                id: paletteFlow
                width: parent.width
                spacing: Tokens.gap
                readonly property int columns: Math.max(1, Math.floor((width + spacing) / 230))
                readonly property real cardW: Math.floor((width - (columns - 1) * spacing) / columns)
                Repeater {
                    id: paletteRep
                    model: ed.catalog
                    delegate: PaletteCard {
                        required property var modelData
                        ed: editorItem
                        entry: modelData
                        width: paletteFlow.cardW
                    }
                }
            }
        }

        // ------------------------------------------------- drop indicators, ghost ---
        // Into an island: a lit caret between its chips.
        Rectangle {
            z: 50
            readonly property var t: ed.dropTarget
            visible: ed.dragging && t !== null && t.kind === "island"
            x: visible ? t.ind.x : 0
            y: visible ? t.ind.y : 0
            width: 2
            height: visible ? t.ind.height : 0
            radius: 1
            gradient: Gradient {
                GradientStop { position: 0; color: Colors.accent }
                GradientStop { position: 1; color: Colors.accent2 }
            }
        }
        // Into a gap: the gap lit as the island it would become.
        Item {
            z: 50
            readonly property var t: ed.dropTarget
            visible: ed.dragging && t !== null && t.kind === "gap"
            x: visible ? t.ind.x + 3 : 0
            y: visible ? t.ind.y : 0
            width: visible ? Math.max(4, t.ind.width - 6) : 0
            height: visible ? t.ind.height : 0
            ShellTint {
                anchors.fill: parent
                radius: Math.min(Tokens.islandRadius, width / 2)
                active: parent.visible
            }
            Icon {
                anchors.centerIn: parent
                visible: parent.width >= size + 4
                name: "add"
                size: Math.min(Tokens.iconSize, parent.width - 4)
            }
        }
        // The lifted module under the pointer: tinted glass, red-tinted with a
        // bin while it would be removed.
        Item {
            id: ghost
            z: 60
            visible: ed.dragging
            readonly property bool removing: ed.dropTarget !== null && ed.dropTarget.kind === "remove"
            readonly property var entry: ed.infoOf(ed.dragId)
            width: gRow.implicitWidth + ed.chipPad * 2
            height: Tokens.islandHeight
            x: ed.dragX - (ed.dragKind === "bar" && ed.press ? Math.min(ed.press.ox, width - 6) : width / 2)
            y: ed.dragY - height / 2
            opacity: ed.dropTarget === null ? 0.7 : 1
            Rectangle {
                anchors { fill: parent; topMargin: 3; bottomMargin: -3 }
                radius: Tokens.islandRadius
                color: Qt.rgba(0, 0, 0, Colors.dark ? 0.35 : 0.16)
            }
            Surface {
                anchors.fill: parent
                group: "panels"; level: 2
                color: Colors.bg
                radius: Tokens.islandRadius
            }
            ShellTint {
                anchors.fill: parent
                radius: Tokens.islandRadius
                tint: ghost.removing ? Colors.danger : Colors.accent
            }
            Row {
                id: gRow
                anchors.centerIn: parent
                spacing: 5
                Icon { visible: ghost.removing; name: "trash"; anchors.verticalCenter: parent.verticalCenter }
                Icon { visible: !ghost.removing; name: ghost.entry.icon; anchors.verticalCenter: parent.verticalCenter }
                Label { text: (ghost.removing ? "Remove " : "") + ghost.entry.name; size: ed.chipText; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    /*
     * Which bar the editor changes: "All screens" (the shared layout) or one
     * screen, connected or with a layout of its own saved. For a screen, the Own
     * layout switch: on, that screen's bar is edited on its own; switched on the
     * first time, its layout starts as a copy of the shared one.
     */
    component ScreenPicker: Item {
        id: picker
        /// "" for all screens, else a screen's name.
        property string screen: ""
        readonly property var connected: Quickshell.screens.map(s => s.name)
        readonly property var configured: {
            const s = Settings.get("bar.screens", {});
            return s && typeof s === "object" ? Object.keys(s).filter(n => s[n] && s[n].own === true) : [];
        }
        readonly property var names: connected.concat(configured.filter(n => connected.indexOf(n) < 0))
        readonly property bool own: screen !== "" && Settings.get("bar.screens." + screen + ".own", false) === true
        onNamesChanged: if (screen !== "" && names.indexOf(screen) < 0) screen = ""

        function setOwn(on) {
            const base = "bar.screens." + screen;
            const cur = Settings.get(base, {});
            const next = Object.assign({}, cur && typeof cur === "object" ? cur : {}, { own: on });
            if (on && !(next.layout && typeof next.layout === "object" && !Array.isArray(next.layout)))
                next.layout = BarLib.normalize(Settings.get("bar.layout", {}));
            Settings.set(base, next);
        }

        implicitHeight: col.implicitHeight
        Column {
            id: col
            width: parent.width
            spacing: Tokens.gap
            Flow {
                width: parent.width
                spacing: Tokens.gap / 2
                GlassChoice {
                    label: "All screens"; icon: "desktop"
                    chosen: picker.screen === ""
                    onClicked: picker.screen = ""
                }
                Repeater {
                    model: picker.names
                    delegate: GlassChoice {
                        required property string modelData
                        label: modelData + (picker.connected.indexOf(modelData) < 0 ? " (not connected)" : "")
                        icon: "screen"
                        chosen: picker.screen === modelData
                        onClicked: picker.screen = modelData
                    }
                }
            }
            // The screen's own layout, or the shared one.
            Item {
                visible: picker.screen !== ""
                width: parent.width
                height: visible ? Math.max(ownText.implicitHeight, sw.height) + Tokens.gap : 0
                Column {
                    id: ownText
                    anchors { left: parent.left; leftMargin: Tokens.padding * 0.5; right: sw.left; rightMargin: Tokens.gap; verticalCenter: parent.verticalCenter }
                    Label { width: parent.width; text: "Own layout on " + picker.screen }
                    Label {
                        width: parent.width
                        text: picker.own ? "This screen's bar is edited here on its own." : "Off: this screen shows the shared layout of all screens."
                        role: "dim"; size: Tokens.textSmall; wrapMode: Text.WordWrap; elide: Text.ElideNone
                    }
                }
                GlassSwitch {
                    id: sw
                    anchors { right: parent.right; rightMargin: Tokens.padding * 0.5; verticalCenter: parent.verticalCenter }
                    checked: picker.own
                    onToggled: picker.setOwn(!checked)
                }
            }
        }
    }

    /*
     * One side of the editor's bar (left, centre, right, activities): its islands
     * in a row. An empty side is an outlined slot with its name, so there is
     * still somewhere to drop a module.
     */
    component ZoneRow: Item {
        id: zone
        property Item ed
        property string side: ""
        property string caption: ""
        readonly property var islands: ed && ed.layout && ed.layout[side] ? ed.layout[side] : []
        property alias count: rep.count
        function islandAt(i) { return rep.itemAt(i); }

        implicitWidth: ed ? ed.zoneWidth(islands, side) : 0
        width: implicitWidth
        height: Tokens.islandHeight

        // The empty side.
        Rectangle {
            visible: zone.islands.length === 0
            anchors.fill: parent
            radius: Tokens.islandRadius
            color: "transparent"
            border.width: 1
            border.color: Colors.alpha(Colors.text, 0.18)
            Label {
                anchors.centerIn: parent
                text: zone.caption
                role: "dim"
                size: Tokens.textSmall
            }
        }
        Row {
            id: row
            spacing: ed ? ed.islandSpacing : Tokens.gap
            Repeater {
                id: rep
                model: zone.islands
                delegate: IslandBox {
                    required property var modelData
                    required property int index
                    ed: zone.ed
                    side: zone.side
                    islandIndex: index
                    modules: modelData
                }
            }
        }
    }

    /*
     * One island of the editor's bar: a glass piece with the bar's island radius
     * holding its modules as chips. While a drag would drop into it, it is
     * faintly tinted with a lit rim (the caret between its chips is the editor's).
     * Its width is computed (the editor's islandWidth), not sprung: a rebuilt island
     * is at its size at once and the hit test never chases an animation.
     */
    component IslandBox: Item {
        id: isl
        property Item ed
        property string side: ""
        property int islandIndex: 0
        property var modules: []
        property alias count: rep.count
        function chipAt(i) { return rep.itemAt(i); }

        readonly property bool target: ed !== null && ed.dropTarget !== null && ed.dropTarget.kind === "island"
                                       && ed.dropTarget.side === side && ed.dropTarget.island === islandIndex

        width: ed ? ed.islandWidth(modules, side) : 60
        height: Tokens.islandHeight

        Surface {
            anchors.fill: parent
            group: "panels"; level: 2
            radius: Tokens.islandRadius
        }
        ShellTint {
            anchors.fill: parent
            radius: Tokens.islandRadius
            active: isl.target
            alphaStart: dark ? 0.22 : 0.14
            alphaMiddle: dark ? 0.16 : 0.10
            alphaEnd: dark ? 0.20 : 0.12
        }
        Rectangle {
            anchors.fill: parent
            radius: Tokens.islandRadius
            color: "transparent"
            border.width: 1
            border.color: Colors.alpha(Colors.accent, isl.target ? 0.75 : 0)
            Behavior on border.color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
        }
        Row {
            x: ed ? ed.inset : 3
            y: ed ? ed.inset : 3
            spacing: ed ? ed.chipSpacing : 2
            Repeater {
                id: rep
                model: isl.modules
                delegate: ModuleChip {
                    required property string modelData
                    ed: isl.ed
                    side: isl.side
                    moduleId: modelData
                }
            }
        }
    }

    /*
     * One module in the editor's bar: its icon and short name (the icon alone
     * when the bar is too full for names) on clear glass. Selected, it is tinted;
     * lifted (being dragged), it fades to a hole. It has no mouse handling of its
     * own: the editor's one pointer area hit-tests it, so nothing here is lost
     * when the layout changes and the island is rebuilt.
     */
    component ModuleChip: Item {
        id: chip
        property Item ed
        property string moduleId: ""
        property string side: ""
        readonly property var entry: ed ? ed.infoOf(moduleId) : null
        readonly property bool selected: ed !== null && ed.selectedId === moduleId
        readonly property bool hovered: ed !== null && ed.hoverKey === "bar:" + moduleId
        readonly property bool lifted: ed !== null && ed.dragging && ed.dragKind === "bar" && ed.dragId === moduleId

        width: ed ? ed.chipWidth(moduleId, side) : 40
        height: ed ? ed.chipH : 24
        opacity: lifted ? 0.28 : 1
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }

        // The lift under the pointer, on clear glass.
        Rectangle {
            anchors.fill: parent
            radius: ed ? ed.chipRadius : 6
            color: Colors.alpha(Colors.text, !chip.selected && chip.hovered && !chip.ed.dragging ? 0.08 : 0)
            Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
        }
        ShellTint {
            anchors.fill: parent
            radius: ed ? ed.chipRadius : 6
            active: chip.selected
            hovered: chip.hovered
        }
        Row {
            anchors.centerIn: parent
            spacing: 5
            Icon {
                name: chip.entry ? chip.entry.icon : "help"
                size: Tokens.iconSize
                anchors.verticalCenter: parent.verticalCenter
            }
            Label {
                visible: chip.ed !== null && !chip.ed.compactFor(chip.side)
                text: chip.entry ? chip.entry.name : chip.moduleId
                size: chip.ed ? chip.ed.chipText : Tokens.textSmall
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    /*
     * A module in the palette: its icon, name and one line about it, on clear
     * glass. One already in the edited bar is dimmed and says so. Like the chips,
     * it takes no input itself: the editor's pointer area drags it into the bar
     * or, on a click, adds it (or selects it where it already is).
     */
    component PaletteCard: Item {
        id: card
        property Item ed
        property var entry: ({})
        readonly property string moduleId: entry && entry.id ? entry.id : ""
        readonly property bool used: ed !== null && ed.used.indexOf(moduleId) >= 0
        readonly property bool hovered: ed !== null && ed.hoverKey === "pal:" + moduleId && !ed.dragging
        readonly property bool selected: ed !== null && ed.selectedId === moduleId
        readonly property bool lifted: ed !== null && ed.dragging && ed.dragKind === "palette" && ed.dragId === moduleId

        height: Math.round(Tokens.islandHeight * 1.9)
        opacity: lifted ? 0.35 : used && !hovered && !selected ? 0.55 : 1
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }

        Surface {
            anchors.fill: parent
            group: "panels"; level: 1
            radius: Tokens.radiusTile
        }
        Rectangle {
            anchors.fill: parent
            radius: Tokens.radiusTile
            color: Colors.alpha(Colors.text, card.hovered && !card.selected ? 0.06 : 0)
            Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
        }
        ShellTint {
            anchors.fill: parent
            radius: Tokens.radiusTile
            active: card.selected
            hovered: card.hovered
        }
        Icon {
            id: ic
            x: Tokens.padding
            anchors.verticalCenter: parent.verticalCenter
            name: card.entry.icon || "help"
            size: Math.round(Tokens.iconSize * 1.25)
        }
        Column {
            anchors { left: ic.right; leftMargin: Tokens.gap; right: parent.right; rightMargin: Tokens.padding; verticalCenter: parent.verticalCenter }
            spacing: 1
            Item {
                width: parent.width
                height: nm.implicitHeight
                Label {
                    id: nm
                    width: parent.width - (tag.visible ? tag.implicitWidth + Tokens.gap / 2 : 0)
                    text: card.entry.name || card.moduleId
                    font.weight: Font.DemiBold
                }
                Label {
                    id: tag
                    visible: card.used
                    anchors { right: parent.right; verticalCenter: nm.verticalCenter }
                    text: "In bar"
                    role: "dim"
                    size: Tokens.textSmall
                }
            }
            Label {
                width: parent.width
                text: card.entry.description || ""
                role: "dim"
                size: Tokens.textSmall
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }
        }
    }

    /*
     * The selected module's panel under the bar: its icon, name, what it is and
     * where it sits, its options (the catalog's: full settings keys, as Setting*
     * rows) or "No options", and Remove. The editor gives it the module and the
     * place; it says remove() and close().
     */
    component ModuleOptions: Item {
        id: panel
        property var entry: null
        /// "Right, island 2 of 3" — or "" for a module not in the edited bar.
        property string where: ""
        property bool canRemove: true
        signal remove()
        signal close()

        readonly property var options: entry && entry.options ? entry.options : []
        implicitHeight: col.implicitHeight

        Surface {
            anchors.fill: parent
            group: "panels"; level: 1; outlined: false
            radius: Tokens.radiusInner
        }
        Column {
            id: col
            width: parent.width
            Item {
                width: parent.width
                height: Math.max(head.implicitHeight, Tokens.islandHeight) + Tokens.padding * 2
                Icon {
                    id: hi
                    x: Tokens.padding
                    anchors.verticalCenter: parent.verticalCenter
                    name: panel.entry ? panel.entry.icon : "help"
                    size: Math.round(Tokens.iconSize * 1.4)
                }
                Column {
                    id: head
                    anchors { left: hi.right; leftMargin: Tokens.gap; right: buttons.left; rightMargin: Tokens.gap; verticalCenter: parent.verticalCenter }
                    spacing: 1
                    Label { width: parent.width; text: panel.entry ? panel.entry.name : ""; size: Tokens.textLarge; font.weight: Font.DemiBold }
                    Label {
                        width: parent.width
                        text: panel.entry ? panel.entry.description : ""
                        role: "dim"; wrapMode: Text.WordWrap; elide: Text.ElideNone
                    }
                    Label { visible: panel.where.length > 0; width: parent.width; text: panel.where; role: "dim"; size: Tokens.textSmall }
                }
                Row {
                    id: buttons
                    anchors { right: parent.right; rightMargin: Tokens.padding; verticalCenter: parent.verticalCenter }
                    spacing: Tokens.gap
                    GlassButton {
                        visible: panel.where.length > 0
                        enabled: panel.canRemove
                        icon: "trash"; label: "Remove"
                        danger: true
                        labelSize: Tokens.textSmall + 1
                        onClicked: panel.remove()
                    }
                    GlassButton {
                        icon: "close"
                        onClicked: panel.close()
                    }
                }
            }
            Rectangle { width: parent.width - Tokens.padding * 2; x: Tokens.padding; height: 1; color: Colors.alpha(Colors.text, 0.06) }
            Label {
                visible: panel.options.length === 0
                x: Tokens.padding
                height: Tokens.islandHeight * 1.6
                text: "No options"
                role: "dim"
            }
            Repeater {
                model: panel.options
                delegate: Loader {
                    required property var modelData
                    required property int index
                    width: col.width
                    sourceComponent: modelData.type === "choice" ? choiceRow : toggleRow
                }
            }
        }

        // A row per option. The loaded row reads its option off the Loader.
        Component {
            id: toggleRow
            SettingToggle {
                readonly property var opt: parent && parent.modelData ? parent.modelData : ({})
                key: opt.key || ""
                label: opt.label || ""
                // An option that means nothing without another switch (lyrics in the bar without lyrics).
                needs: opt.needs || ""
                divider: !!parent && parent.index < panel.options.length - 1
            }
        }
        Component {
            id: choiceRow
            SettingChoice {
                readonly property var opt: parent && parent.modelData ? parent.modelData : ({})
                key: opt.key || ""
                label: opt.label || ""
                values: opt.values || []
                // The catalog gives names parallel to values; SettingChoice wants a map.
                names: {
                    const m = {};
                    const v = opt.values || [], n = opt.names;
                    if (Array.isArray(n)) v.forEach((x, i) => { if (n[i] !== undefined) m[x] = n[i]; });
                    else if (n && typeof n === "object") return n;
                    return m;
                }
                divider: !!parent && parent.index < panel.options.length - 1
            }
        }
    }
}
