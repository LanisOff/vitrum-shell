import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components
import "../../lib/bar.js" as BarLib

/*
 * One island: a rounded piece holding a list of modules by name
 * (modules/bar/modules/<name>.qml). An island whose modules all hide shrinks
 * away to nothing and comes back the same way — activity islands live on that.
 *
 *   shaped   the bar has shaped glass: the region is a plain rectangle, niri rounds it
 *   merged   a panel is flowing out of this island: the drop paints the tint
 */
Island {
    id: root
    property var modules: []
    property var screen: null
    property bool primary: false
    property bool shaped: false
    property bool merged: false
    /// Let go of by its side's Repeater: it is about to be deleted.
    property bool gone: false
    // In the window's frame, from this island's and its row's positions: a
    // Region given `item` follows only the item's own x, not its row's — and
    // the centre row re-centres on every width change, which left the glass
    // behind the island while it moved.
    readonly property Region region: Region {
        x: (root.parent ? root.parent.x : 0) + root.x
        y: (root.parent ? root.parent.y : 0) + root.y
        // Nothing once the island is out of its row (a moment before it is deleted).
        width: root.parent && !root.gone ? root.width : 0
        height: root.parent && !root.gone ? root.height : 0
        radius: root.shaped ? 0 : root.radius
    }
    property int visibleModules: 0
    readonly property bool active: visibleModules > 0
    // By what the modules want, not by `visible`: inside a hidden island every
    // child reads as hidden, and the island would never come back.
    function _count() {
        let n = 0;
        for (let i = 0; i < loaders.count; i++) {
            const l = loaders.itemAt(i);
            if (l && l.wanted) n++;
        }
        visibleModules = n;
    }

    // Does a module here open this panel?
    function opens(name) {
        for (let i = 0; i < loaders.count; i++) {
            const l = loaders.itemAt(i);
            if (l && l.item && l.item.shown && l.item.panel === name) return true;
        }
        return false;
    }

    /// For the debug probe: "<address>: id@<address> …".
    function probe() {
        const addr = o => String(o).replace(/^.*\(0x/, "").replace(/[,)].*$/, "");
        const out = [];
        for (let i = 0; i < loaders.count; i++) {
            const l = loaders.itemAt(i);
            if (l) out.push(l.mid + "@" + addr(l.item));
        }
        return addr(root) + ": " + out.join(" ");
    }

    targetWidth: active ? implicitWidth : 0
    visible: width > 0
    clip: true
    color: merged ? "transparent" : Materials.fill(group, level, Screen.name)
    outlined: !merged

    // The modules as a ListModel changed only where the list changed
    // (lib/bar.js planList): a module that stays keeps its state when one is
    // added, removed or moved next to it.
    readonly property ListModel _rows: ListModel {}
    property var _ids: []
    function _sync() {
        const want = (root.modules || []).filter(m => typeof m === "string" && m.length > 0);
        for (const o of BarLib.planList(_ids, want)) {
            if (o.op === "remove") _rows.remove(o.index, 1);
            else if (o.op === "move") _rows.move(o.from, o.to, 1);
            else _rows.insert(o.index, { mid: o.key });
        }
        _ids = want;
    }
    onModulesChanged: _sync()
    Component.onCompleted: _sync()

    Repeater {
        id: loaders
        model: root._rows
        onItemAdded: root._count()
        onItemRemoved: Qt.callLater(root._count)
        delegate: Loader {
            required property string mid
            source: "modules/" + mid + ".qml"
            readonly property bool wanted: status === Loader.Ready && !!item && item.shown
            visible: wanted
            onWantedChanged: root._count()
            onLoaded: { item.screen = Qt.binding(() => root.screen); item.primary = Qt.binding(() => root.primary); item.island = root; }
        }
    }
}
