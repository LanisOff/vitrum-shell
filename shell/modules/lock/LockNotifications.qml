import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components
import "root:/lib/lock.js" as Lib

// What arrived while locked, grouped by app: glass cards (Tokens.radiusTile)
// with the app's icon, and a count badge in the dichroic tint when there is
// more than one. lock.notifications decides how much they say (off / app
// names / full text). With full text a click opens a group to its newest few
// (the badge's tint drifts while it is open); new groups slide in.
Column {
    id: list
    property real since: Date.now()
    property Item backdrop: null
    property Item source: null
    readonly property string mode: Settings.get("lock.notifications", "full")
    /// The room there is (above the player): as many groups as fit, at most
    /// three; the ones that do not are a line at the end ("2 more · Steam, Mail").
    property real maxHeight: Infinity
    readonly property real cardH: Tokens.islandHeight * 1.25 + Tokens.padding * 1.2
    readonly property real pillH: Tokens.islandHeight
    readonly property var all: Lib.lockNotifications(Notifs.history, list.since, list.mode, 99)
    readonly property int fits: {
        const n = Math.min(3, all.length);
        const plain = Math.floor((maxHeight + spacing) / (cardH + spacing));
        if (plain >= n) return n;
        // Not all of them: room for the line too.
        return Math.max(0, Math.floor((maxHeight - pillH) / (cardH + spacing)));
    }
    /// The height it would take with room to spare (LockView lifts the centre for it).
    readonly property real wanted: {
        const n = Math.min(3, all.length);
        return n ? n * cardH + (n - 1) * spacing + (all.length > n ? spacing + pillH : 0) : 0;
    }
    readonly property var groups: all.slice(0, fits)
    readonly property var rest: all.slice(fits)
    property string opened: ""
    onSinceChanged: opened = ""
    spacing: Tokens.gap * 0.6
    width: Tokens.islandHeight * 11

    add: Transition {
        enabled: Motion.enabled
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.standard }
        NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: Motion.standard; easing.type: Easing.OutCubic }
    }
    move: Transition { enabled: Motion.enabled; NumberAnimation { properties: "y"; duration: Motion.standard; easing.type: Easing.OutCubic } }

    Repeater {
        model: list.groups
        delegate: LockGlass {
            id: card
            required property var modelData
            readonly property bool open: list.opened === modelData.app && modelData.items.length > 1
            readonly property real rowH: Tokens.islandHeight * 1.2
            backdrop: list.backdrop
            source: list.source
            width: list.width
            radius: Tokens.radiusTile
            readonly property bool canOpen: modelData.items.length > 1
            tint: cardMouse.containsMouse && canOpen ? Colors.alpha(Colors.text, 0.12) : Qt.rgba(1, 1, 1, Colors.dark ? 0.07 : 0.16)
            Behavior on tint { enabled: Motion.enabled; ColorAnim {} }
            height: head.height + (open ? more.implicitHeight + Tokens.gap * 0.5 : 0) + Tokens.padding * 1.2
            Behavior on height { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }
            clip: true

            MouseArea {
                id: cardMouse
                anchors.fill: parent
                enabled: card.canOpen
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: list.opened = card.open ? "" : card.modelData.app
            }
            Row {
                id: head
                x: Tokens.padding; y: Tokens.padding * 0.6
                width: parent.width - 2 * Tokens.padding
                height: Tokens.islandHeight * (card.modelData.title || card.modelData.body ? 1.25 : 0.8)
                spacing: Tokens.gap
                // The app's own icon; without one, a bell on a small square of glass.
                Rectangle {
                    width: Tokens.iconSize * 1.6; height: width
                    anchors.verticalCenter: parent.verticalCenter
                    radius: Tokens.radiusButton
                    color: appIcon.visible ? "transparent" : Colors.alpha(Colors.text, 0.08)
                    border.width: appIcon.visible ? 0 : Tokens.hairline
                    border.color: Colors.alpha(Colors.text, 0.14)
                    IconImage { id: appIcon; anchors.fill: parent; source: card.modelData.icon ? Quickshell.iconPath(card.modelData.icon, true) : ""; visible: status === Image.Ready }
                    Icon { anchors.centerIn: parent; name: "notifications"; visible: !appIcon.visible; color: Colors.textDim }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Tokens.iconSize * 1.6 - countPill.width - 2 * Tokens.gap
                    spacing: 1
                    Label { width: parent.width; text: card.modelData.title ? card.modelData.app + " · " + card.modelData.title : card.modelData.app; font.weight: Font.DemiBold; elide: Text.ElideRight }
                    Label { width: parent.width; visible: card.modelData.body.length > 0; text: card.modelData.body; role: "dim"; size: Tokens.textSmall; elide: Text.ElideRight; opacity: card.open ? 0 : 1 }
                }
                // How many, when grouped: a small badge in the dichroic tint
                // (it drifts while the group is open).
                Item {
                    id: countPill
                    anchors.verticalCenter: parent.verticalCenter
                    visible: card.modelData.count > 1
                    width: visible ? Math.max(height * 1.3, cnt.implicitWidth + Tokens.gap * 1.4) : 0; height: Tokens.iconSize * 1.25
                    ShellTint { anchors.fill: parent; radius: Tokens.radiusButton; group: "lock"; active: countPill.visible; hovered: card.open }
                    Label { id: cnt; anchors.centerIn: parent; text: card.modelData.count; size: Tokens.textSmall; numeric: true; font.weight: Font.DemiBold }
                }
            }
            // The group, open: each one with its full text.
            Column {
                id: more
                x: Tokens.padding + Tokens.iconSize * 1.6 + Tokens.gap
                y: head.y + head.height + Tokens.gap * 0.5
                width: card.width - x - Tokens.padding
                spacing: Tokens.gap * 0.6
                opacity: card.open ? 1 : 0
                Behavior on opacity { enabled: Motion.enabled; EaseAnim {} }
                Repeater {
                    model: card.open ? card.modelData.items : []
                    delegate: Column {
                        required property var modelData
                        width: more.width
                        Label { width: parent.width; text: modelData.title; font.weight: Font.DemiBold; elide: Text.ElideRight; visible: text.length > 0 }
                        Label { width: parent.width; text: modelData.body; role: "dim"; size: Tokens.textSmall; wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight; visible: text.length > 0 }
                    }
                }
            }
        }
    }

    // The rest, as one line.
    LockGlass {
        visible: list.rest.length > 0 && list.maxHeight >= list.pillH
        backdrop: list.backdrop
        source: list.source
        width: Math.min(list.width, moreRow.implicitWidth + Tokens.padding * 2)
        height: list.pillH
        radius: Tokens.islandRadius
        anchors.horizontalCenter: parent.horizontalCenter
        Row {
            id: moreRow
            anchors.centerIn: parent
            spacing: Tokens.gap * 0.6
            Icon { name: "notifications"; size: Tokens.iconSize; color: Colors.textDim; anchors.verticalCenter: parent.verticalCenter }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: (list.rest.reduce((a, g) => a + g.count, 0)) + " more · " + list.rest.map(g => g.app).join(", ")
                role: "dim"; size: Tokens.textSmall + 1
                width: Math.min(implicitWidth, list.width - Tokens.padding * 2 - Tokens.iconSize - Tokens.gap)
            }
        }
    }
}
