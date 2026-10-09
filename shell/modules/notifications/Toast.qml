import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components

// One notification card: icon, app, summary, body, actions; swipe right or × to dismiss; hover holds it.
Surface {
    id: root
    required property var item
    property int count: 1                      // how many from this app are stacked under it
    readonly property bool critical: item.urgency === 2
    property bool replying: false
    readonly property Region region: Region { item: root; radius: root.radius }
    group: "notifications"
    radius: Tokens.radiusPanel
    width: Tokens.islandHeight * 12
    implicitHeight: body.implicitHeight + 2 * Tokens.padding
    border.color: critical ? Colors.danger : Materials.border("notifications")

    // Slide in from the edge; swipe out.
    property real offset: width + Tokens.gap
    x: offset + drag.translation.x
    Component.onCompleted: offset = 0
    Behavior on offset { enabled: Motion.enabled; NumberAnimation { duration: Motion.emphasized; easing.type: Easing.OutQuint } }
    opacity: 1 - Math.max(0, drag.translation.x) / width

    Timer {
        running: !root.critical && !hover.hovered && !drag.active && !root.replying
        interval: Notifs.timeout * 1000
        onTriggered: Notifs.dismissPopup(root.item.id)
    }
    HoverHandler { id: hover }
    DragHandler {
        id: drag
        target: null              // we read translation; moving the card ourselves keeps the x binding
        xAxis.minimum: 0
        yAxis.enabled: false
        onActiveChanged: if (!active && translation.x > root.width * 0.35) Notifs.dismissPopup(root.item.id)
    }
    TapHandler { onTapped: Notifs.activate(root.item) }

    Row {
        id: body
        x: Tokens.padding; y: Tokens.padding
        width: parent.width - 2 * Tokens.padding
        spacing: Tokens.gap
        Item {
            width: Tokens.iconSize * 2; height: width
            IconImage { anchors.fill: parent; source: root.item.image || (root.item.appIcon ? Quickshell.iconPath(root.item.appIcon, true) : ""); visible: status === Image.Ready }
            Icon { anchors.centerIn: parent; name: "notifications"; visible: !parent.children[0].visible; color: Colors.accent }
        }
        Column {
            width: parent.width - Tokens.iconSize * 2 - Tokens.gap
            spacing: 2
            Row {
                width: parent.width
                Label { text: root.item.appName + (root.count > 1 ? "  ·  +" + (root.count - 1) : ""); role: "dim"; size: Tokens.textSmall; width: parent.width - Tokens.iconSize }
                Icon { name: "close"; size: Tokens.iconSize * 0.8; color: Colors.textDim; MouseArea { anchors.fill: parent; onClicked: Notifs.dismissPopup(root.item.id) } }
            }
            Label { width: parent.width; text: root.item.summary; font.weight: Font.DemiBold; wrapMode: Text.WordWrap; maximumLineCount: 2 }
            Label { width: parent.width; visible: text.length > 0; text: root.item.body; role: "dim"; textFormat: Text.StyledText; wrapMode: Text.WordWrap; maximumLineCount: 4 }
            Row {
                visible: root.item.actions && root.item.actions.length > 0
                spacing: Tokens.gap / 2
                Repeater {
                    model: (root.item.actions || []).filter(a => a.identifier !== "default")
                    Capsule { required property var modelData; label: modelData.text; onClicked: Notifs.invoke(root.item, modelData.identifier) }
                }
            }
            // A reply, right here (apps that take one: Telegram, KDE Connect).
            Rectangle {
                visible: root.item.canReply === true
                width: parent.width
                height: Tokens.islandHeight
                radius: height / 2
                color: Colors.alpha(Colors.text, replyInput.activeFocus ? 0.12 : 0.07)
                Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
                TextInput {
                    id: replyInput
                    anchors { left: parent.left; right: send.left; verticalCenter: parent.verticalCenter; leftMargin: Tokens.padding; rightMargin: Tokens.gap }
                    font.family: Tokens.fontText; font.pixelSize: Tokens.textSize
                    color: Colors.text; selectionColor: Colors.accent
                    clip: true
                    onAccepted: Notifs.reply(root.item, text)
                    onActiveFocusChanged: root.replying = activeFocus || text.length > 0
                    Label { visible: !replyInput.text && !replyInput.activeFocus; text: root.item.replyPlaceholder || "Reply…"; role: "dim"; anchors.verticalCenter: parent.verticalCenter }
                }
                Icon {
                    id: send
                    name: "send"; color: replyInput.text ? Colors.accent : Colors.textDim
                    anchors { right: parent.right; rightMargin: Tokens.gap; verticalCenter: parent.verticalCenter }
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.reply(root.item, replyInput.text) }
                }
            }
        }
    }
}
