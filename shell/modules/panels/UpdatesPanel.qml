import QtQuick
import qs.services
import qs.theme
import qs.components
import "../../lib/emerge.js" as Lib

// The package manager (Portage, pacman, xbps or dnf): what runs now, and what
// waits. xbps and dnf give no steps to count (Packages.logless): their run is
// "Updating…" and how long it has run so far.
Column {
    id: root
    spacing: Tokens.gap
    width: Tokens.islandHeight * 12

    Card {
        visible: Packages.state.running
        width: root.width
        Column {
            width: root.width - 2 * Tokens.padding
            spacing: Tokens.gap / 2
            Label {
                font.weight: Font.DemiBold
                text: Packages.logless ? "Updating…"
                    : Packages.gentoo ? "Building " + (Packages.state.done + 1) + " of " + Packages.state.total
                    : Packages.state.done === 0 ? "Downloading…"
                    : Packages.state.total ? "Installing " + Math.min(Packages.state.done + 1, Packages.state.total) + " of " + Packages.state.total
                    : Packages.state.done + " installed"
            }
            Label { width: parent.width; text: Packages.state.current; role: "dim"; elide: Text.ElideMiddle }
            Meter {
                visible: !Packages.logless
                width: parent.width
                value: Packages.state.total ? Packages.state.done / Packages.state.total : 0
            }
            Label { visible: text.length > 0; role: "dim"; size: Tokens.textSmall
                    text: Packages.logless ? "Running for " + Math.max(1, Math.round((Packages.now - Packages.state.started) / 60)) + " min, in its terminal window"
                        : Lib.formatEta(Packages.secondsLeft) + (Packages.secondsLeft >= 0 ? " left" : "") }
        }
    }
    Label { visible: !Packages.readable; width: root.width; wrapMode: Text.WordWrap; role: "dim"; text: Packages.gentoo ? "Build progress shows after the next login (you were added to the portage group)." : "pacman's log cannot be read." }

    Row {
        width: root.width
        spacing: Tokens.gap
        Label { text: Packages.checking ? "Checking for updates…" : Packages.updates.length ? Packages.updates.length + " updates" : "Up to date"; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - up.width - Tokens.gap }
        GlassButton { id: up; visible: Packages.updates.length > 0 && !Packages.state.running; icon: "update"; label: "Update"; primary: true; onClicked: { UiState.closePanel(); Packages.update(); } }
    }
    Flickable {
        width: root.width
        height: Math.min(contentHeight, Tokens.islandHeight * 8)
        contentHeight: list.implicitHeight
        clip: true
        Column {
            id: list
            width: root.width
            Repeater {
                model: Packages.updates
                // The name on the left, from → to on the right. The versions
                // get up to 60% of the width and the name the rest; a version
                // longer than its share is cut in the middle, and under the
                // pointer such a row opens to two lines with both in full.
                Item {
                    id: pkg
                    required property var modelData
                    width: list.width
                    height: open ? atomL.height + vers.height : Math.max(atomL.height, vers.height)
                    readonly property bool hasFrom: !!modelData.from
                    // Each version's width in a room: the new one keeps at least
                    // half, or all the old one leaves.
                    function toIn(room) { return Math.min(toL.implicitWidth, Math.max(room / 2, room - (hasFrom ? fromL.implicitWidth : 0))); }
                    function fromIn(room) { return hasFrom ? Math.min(fromL.implicitWidth, room - toIn(room)) : 0; }
                    readonly property real arrow: hasFrom ? chev.width + 2 * vers.spacing : 0
                    readonly property real shut: Math.max(0, width * 0.6 - arrow)
                    readonly property bool cut: toIn(shut) < toL.implicitWidth || (hasFrom && fromIn(shut) < fromL.implicitWidth)
                    readonly property bool open: cut && hover.hovered
                    readonly property real room: open ? Math.max(0, width - arrow) : shut
                    HoverHandler { id: hover }
                    Label {
                        id: atomL
                        width: pkg.open ? pkg.width : Math.max(0, pkg.width - vers.width - Tokens.gap)
                        y: pkg.open ? 0 : (pkg.height - height) / 2
                        text: modelData.atom; elide: Text.ElideMiddle
                    }
                    Row {
                        id: vers
                        anchors.right: parent.right
                        y: pkg.open ? atomL.height : (pkg.height - height) / 2
                        spacing: 2
                        Label { id: fromL; visible: pkg.hasFrom; width: pkg.fromIn(pkg.room); text: modelData.from || ""; elide: Text.ElideMiddle
                                role: "dim"; size: Tokens.textSmall; numeric: true; anchors.verticalCenter: parent.verticalCenter }
                        Icon { id: chev; visible: pkg.hasFrom; name: "chevron"; size: Tokens.textSmall; color: Colors.textDim; anchors.verticalCenter: parent.verticalCenter }
                        Label { id: toL; width: pkg.toIn(pkg.room); text: (modelData.from ? "" : "new ") + modelData.to; elide: Text.ElideMiddle
                                role: "dim"; size: Tokens.textSmall; numeric: true; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }
}
