import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components

/*
 * The notification centre, as a bar panel: it flows out of the notifications
 * island like the other panels, on the bar's glass, as tall as the screen
 * allows. The history grouped by app (newest first), Do not disturb, clear
 * all; a card opens what sent it, its × dismisses it.
 */
Item {
    id: root
    width: Tokens.islandHeight * 12
    // Down to the bottom of the screen: the bar, the neck and the margins off.
    implicitHeight: Math.max(Tokens.islandHeight * 6, (Window.height || 900) - Tokens.islandHeight - 6 * Tokens.gap - 2 * Tokens.padding)

    Component.onCompleted: Notifs.markAllRead()

    Column {
        anchors.fill: parent
        spacing: Tokens.gap
        Row {
            width: parent.width
            spacing: Tokens.gap
            Label { text: "Notifications"; size: Tokens.textLarge; font.weight: Font.DemiBold; width: parent.width - dnd.width - clear.width - 2 * Tokens.gap; anchors.verticalCenter: parent.verticalCenter }
            Capsule { id: dnd; icon: "dnd"; active: Notifs.doNotDisturb; onClicked: Notifs.setDoNotDisturb(!Notifs.doNotDisturb) }
            Capsule { id: clear; icon: "clear"; onClicked: Notifs.clearHistory() }
        }
        Label { visible: Notifs.history.length === 0; text: "Nothing new"; role: "dim" }
        ListView {
            id: list
            width: parent.width
            height: parent.height - y
            clip: true
            spacing: Tokens.gap
            model: Notifs.grouped()
            add: Transition { enabled: Motion.enabled; NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.standard } }
            displaced: Transition { enabled: Motion.enabled; NumberAnimation { properties: "y"; duration: Motion.standard; easing.type: Easing.OutCubic } }
            delegate: Column {
                id: appGroup
                required property var modelData
                required property int index
                width: ListView.view.width
                spacing: 4
                // Cards rise in one after another as the panel opens.
                opacity: 0
                Component.onCompleted: appear.start()
                SequentialAnimation {
                    id: appear
                    PauseAnimation { duration: Motion.enabled ? 60 + appGroup.index * 45 : 0 }
                    ParallelAnimation {
                        NumberAnimation { target: appGroup; property: "opacity"; to: 1; duration: Motion.enabled ? Motion.standard : 0; easing.type: Easing.OutCubic }
                        NumberAnimation { target: shift; property: "y"; from: Tokens.gap * 2; to: 0; duration: Motion.enabled ? Motion.emphasized : 0; easing.type: Easing.OutCubic }
                    }
                }
                transform: Translate { id: shift }
                Row {
                    spacing: Tokens.gap * 0.6
                    IconImage { width: Tokens.iconSize; height: width; source: appGroup.modelData.items[0].appIcon ? Quickshell.iconPath(appGroup.modelData.items[0].appIcon, true) : ""; visible: status === Image.Ready; anchors.verticalCenter: parent.verticalCenter }
                    Label { text: appGroup.modelData.appName; role: "dim"; size: Tokens.textSmall; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                }
                Repeater {
                    model: appGroup.modelData.items.slice(0, 4)
                    Card {
                        required property var modelData
                        // The bar's glass, raised: the centre is glass through and through.
                        group: "bar"
                        width: appGroup.width
                        Column {
                            width: parent.parent.width - 2 * Tokens.padding
                            Row {
                                width: parent.width
                                Label { text: modelData.summary; font.weight: Font.DemiBold; width: parent.width - Tokens.iconSize * 4; elide: Text.ElideRight }
                                Label { text: Qt.formatTime(new Date(modelData.time), "hh:mm"); role: "dim"; size: Tokens.textSmall; numeric: true; width: Tokens.iconSize * 3; horizontalAlignment: Text.AlignRight }
                                Icon { name: "close"; size: Tokens.iconSize * 0.8; color: Colors.textDim; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.close(modelData) } }
                            }
                            Label { width: parent.width; visible: text.length > 0; text: modelData.body; role: "dim"; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight; textFormat: Text.StyledText }
                        }
                        TapHandler { onTapped: { Notifs.activate(modelData); UiState.closePanel(); } }
                    }
                }
            }
        }
    }
}
