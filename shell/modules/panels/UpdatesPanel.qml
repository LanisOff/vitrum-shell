import QtQuick
import qs.services
import qs.theme
import qs.components
import "../../lib/emerge.js" as Lib

// The package manager (Portage or pacman): what runs now, and what waits.
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
                text: Packages.gentoo ? "Building " + (Packages.state.done + 1) + " of " + Packages.state.total
                    : Packages.state.done === 0 ? "Downloading…"
                    : Packages.state.total ? "Installing " + Math.min(Packages.state.done + 1, Packages.state.total) + " of " + Packages.state.total
                    : Packages.state.done + " installed"
            }
            Label { width: parent.width; text: Packages.state.current; role: "dim"; elide: Text.ElideMiddle }
            Rectangle {
                width: parent.width; height: 6; radius: 3; color: Colors.alpha(Colors.text, 0.12)
                Rectangle { width: parent.width * (Packages.state.total ? Packages.state.done / Packages.state.total : 0); height: parent.height; radius: 3; color: Colors.accent
                            Behavior on width { enabled: Motion.enabled; NumberAnimation { duration: Motion.standard } } }
            }
            Label { visible: text.length > 0; text: Lib.formatEta(Packages.secondsLeft) + (Packages.secondsLeft >= 0 ? " left" : ""); role: "dim"; size: Tokens.textSmall }
        }
    }
    Label { visible: !Packages.readable; width: root.width; wrapMode: Text.WordWrap; role: "dim"; text: Packages.gentoo ? "Build progress shows after the next login (you were added to the portage group)." : "pacman's log cannot be read." }

    Row {
        width: root.width
        spacing: Tokens.gap
        Label { text: Packages.checking ? "Checking for updates…" : Packages.updates.length ? Packages.updates.length + " updates" : "Up to date"; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - up.width - Tokens.gap }
        Capsule { id: up; visible: Packages.updates.length > 0 && !Packages.state.running; icon: "update"; label: "Update"; active: true; onClicked: { UiState.closePanel(); Packages.update(); } }
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
                Row {
                    required property var modelData
                    spacing: Tokens.gap
                    width: list.width
                    Label { width: parent.width * 0.62; text: modelData.atom; elide: Text.ElideMiddle }
                    Row {
                        spacing: 2
                        Label { visible: !!modelData.from; text: modelData.from || ""; role: "dim"; size: Tokens.textSmall; numeric: true; anchors.verticalCenter: parent.verticalCenter }
                        Icon { visible: !!modelData.from; name: "chevron"; size: Tokens.textSmall; color: Colors.textDim; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: (modelData.from ? "" : "new ") + modelData.to; role: "dim"; size: Tokens.textSmall; numeric: true; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }
}
