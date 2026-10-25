import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components

// One notification card: icon, app, summary, body, actions; swipe it off its edge or × to dismiss; hover holds it.
Surface {
    id: root
    required property var item
    property int count: 1                      // how many from this app are stacked under it
    readonly property bool critical: item.urgency === 2
    property bool replying: false
    /// The screen edge it sits at: 1 right, -1 left. It slides in from that edge and is swiped off over it.
    property int side: 1
    readonly property Region region: Region { item: root; radius: root.radius }
    group: "notifications"
    radius: Tokens.radiusPanel
    width: Tokens.islandHeight * 12
    implicitHeight: body.implicitHeight + 2 * Tokens.padding
    border.color: critical ? Colors.danger : Materials.border("notifications")

    // Slide in from the edge; swipe out.
    property real offset: side * (width + Tokens.gap)
    x: offset + side * swipe
    Component.onCompleted: offset = 0
    Behavior on offset { enabled: Motion.enabled; NumberAnimation { duration: Motion.emphasized; easing.type: Easing.OutQuint } }
    opacity: 1 - Math.min(1, swipe / width)

    // The card is the app's: its newest gets the full time (restarted when
    // one arrives), and when it is up the app's older ones go with it — else
    // the next one surfaced after a timer that had already fired, and stayed.
    Timer {
        id: expire
        running: !root.critical && !hover.hovered && !drag.active && !fly.running && !root.replying
        interval: Notifs.timeout * 1000
        onTriggered: Notifs.dismissApp(root.item.appName)
    }
    HoverHandler { id: hover }

    // Swiped toward its edge only (`side`). The distance is read in the window's frame:
    // the card moves under the pointer, and its own translation chased itself
    // (the card lagged and never got to the threshold). Let go past a third of
    // the width or flicked, it flies off at the flick's speed; else back.
    property real swipe: 0
    property real flick: 0
    readonly property real away: width + 2 * Tokens.gap
    DragHandler {
        id: drag
        target: null
        yAxis.enabled: false
        onCentroidChanged: if (active) {
            root.swipe = Math.max(0, root.side * (centroid.scenePosition.x - centroid.scenePressPosition.x));
            root.flick = root.side * centroid.velocity.x;
        }
        onActiveChanged: {
            if (active) { settle.stop(); return; }
            if (root.swipe > root.width / 3 || root.flick > 600) root.flyOff(Math.max(root.flick, 0));
            else settle.start();
        }
    }
    function flyOff(v) {
        // Out-easing starts at twice the average speed: the flick's own, at the least a brisk one.
        fly.duration = Math.max(80, Math.min(Motion.standard, 2000 * (away - swipe) / Math.max(v, 1500)));
        fly.start();
    }
    // The card stays for the app's next one (Toasts keeps cards by app): it slides back in.
    onItemChanged: {
        if (swipe > 0 && !drag.active) { fly.stop(); settle.start(); }
        if (expire.running) expire.restart();
    }
    NumberAnimation { id: settle; target: root; property: "swipe"; to: 0; duration: Motion.standard; easing.type: Easing.OutCubic }
    NumberAnimation { id: fly; target: root; property: "swipe"; to: root.away; easing.type: Easing.OutQuad
                      onFinished: Notifs.dismissPopup(root.item.id) }
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
                    // The first action is the main one: tinted; the rest clear glass.
                    GlassButton { required property var modelData; required property int index; group: "notifications"; primary: index === 0
                                  label: modelData.text; onClicked: Notifs.invoke(root.item, modelData.identifier) }
                }
            }
            // A reply, right here (apps that take one: Telegram, KDE Connect).
            Rectangle {
                visible: root.item.canReply === true
                width: parent.width
                height: Tokens.islandHeight
                radius: Tokens.radiusButton
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
