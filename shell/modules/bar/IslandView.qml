import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components

/*
 * One island: a capsule holding a list of modules by name
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
    // In the window's frame, from this island's and its row's positions: a
    // Region given `item` follows only the item's own x, not its row's — and
    // the centre row re-centres on every width change, which left the glass
    // behind the island while it moved.
    readonly property Region region: Region {
        x: (root.parent ? root.parent.x : 0) + root.x
        y: (root.parent ? root.parent.y : 0) + root.y
        width: root.width
        height: root.height
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

    targetWidth: active ? implicitWidth : 0
    visible: width > 0
    clip: true
    color: merged ? "transparent" : Materials.fill(group, level)
    outlined: !merged

    Repeater {
        id: loaders
        model: root.modules
        onItemAdded: root._count()
        onItemRemoved: Qt.callLater(root._count)
        delegate: Loader {
            required property string modelData
            source: "modules/" + modelData + ".qml"
            readonly property bool wanted: status === Loader.Ready && !!item && item.shown
            visible: wanted
            onWantedChanged: root._count()
            onLoaded: { item.screen = Qt.binding(() => root.screen); item.primary = Qt.binding(() => root.primary); item.island = root; }
        }
    }
}
