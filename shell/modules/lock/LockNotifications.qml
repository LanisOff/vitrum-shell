import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components
import "root:/lib/lock.js" as Lib

// What arrived while locked, grouped by app, on glass: lock.notifications
// decides how much it says (off / app names / full text). With full text a
// click opens a group to its newest few; new groups slide in.
Column {
    id: list
    property real since: Date.now()
    property Item backdrop: null
    property Item source: null
    readonly property string mode: Settings.get("lock.notifications", "full")
    readonly property var groups: Lib.lockNotifications(Notifs.history, list.since, list.mode, 3)
    property string opened: ""
    onSinceChanged: opened = ""
    spacing: Tokens.gap * 0.6
    width: Tokens.islandHeight * 11

    add: Transition {
        enabled: Motion.enabled
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.standard }
        NumberAnimation { property: "scale"; from: 0.92; to: 1; duration: Motion.standard; easing.type: Easing.OutBack }
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
            radius: Tokens.radiusInner * 1.5
            height: head.height + (open ? more.implicitHeight + Tokens.gap * 0.5 : 0) + Tokens.padding * 1.2
            Behavior on height { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }
            clip: true

            MouseArea {
                anchors.fill: parent
                enabled: card.modelData.items.length > 1
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: list.opened = card.open ? "" : card.modelData.app
            }
            Row {
                id: head
                x: Tokens.padding; y: Tokens.padding * 0.6
                width: parent.width - 2 * Tokens.padding
                height: Tokens.islandHeight * (card.modelData.title || card.modelData.body ? 1.25 : 0.8)
                spacing: Tokens.gap
                Item {
                    width: Tokens.iconSize * 1.4; height: width
                    anchors.verticalCenter: parent.verticalCenter
                    IconImage { id: appIcon; anchors.fill: parent; source: card.modelData.icon ? Quickshell.iconPath(card.modelData.icon, true) : ""; visible: status === Image.Ready }
                    Icon { anchors.centerIn: parent; name: "notifications"; visible: appIcon.status !== Image.Ready; color: Colors.textDim }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Tokens.iconSize * 1.4 - countPill.width - 2 * Tokens.gap
                    spacing: 1
                    Label { width: parent.width; text: card.modelData.title ? card.modelData.app + " · " + card.modelData.title : card.modelData.app; font.weight: Font.DemiBold; elide: Text.ElideRight }
                    Label { width: parent.width; visible: card.modelData.body.length > 0; text: card.modelData.body; role: "dim"; size: Tokens.textSmall; elide: Text.ElideRight; opacity: card.open ? 0 : 1 }
                }
                Rectangle {
                    id: countPill
                    anchors.verticalCenter: parent.verticalCenter
                    visible: card.modelData.count > 1
                    width: visible ? Math.max(height, cnt.implicitWidth + Tokens.gap) : 0; height: Tokens.iconSize * 1.2; radius: height / 2
                    color: Colors.alpha(Colors.accent, card.open ? 0.5 : 0.3)
                    Label { id: cnt; anchors.centerIn: parent; text: card.modelData.count; size: Tokens.textSmall; numeric: true; font.weight: Font.DemiBold }
                }
            }
            // The group, open: each one with its full text.
            Column {
                id: more
                x: Tokens.padding + Tokens.iconSize * 1.4 + Tokens.gap
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
}
