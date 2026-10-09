import QtQuick
import qs.services
import qs.theme
import qs.components

/*
 * Who is using the microphone, the camera and the screen, with a way to stop:
 * the microphone is muted for those streams, a screen share is ended. The
 * camera cannot be taken away from an app here, only named.
 */
Column {
    id: root
    spacing: Tokens.gap
    width: Tokens.islandHeight * 9

    Label { text: "In use"; size: Tokens.textLarge; font.weight: Font.DemiBold }

    component Use: Card {
        id: use
        property string icon: ""
        property color tint: Colors.accent
        property string title: ""
        property var apps: []
        property string action: ""
        signal act()
        visible: apps.length > 0
        width: root.width
        Row {
            spacing: Tokens.gap
            width: root.width - 2 * Tokens.padding
            Rectangle {
                width: Tokens.islandHeight; height: width; radius: width / 2
                color: Colors.alpha(use.tint, 0.22)
                anchors.verticalCenter: parent.verticalCenter
                Icon { anchors.centerIn: parent; name: use.icon; color: use.tint; filled: true }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Tokens.islandHeight - stop.width - 2 * Tokens.gap
                Label { text: use.title; font.weight: Font.DemiBold }
                Label { width: parent.width; text: use.apps.join(", "); role: "dim"; elide: Text.ElideRight }
            }
            Capsule { id: stop; visible: use.action.length > 0; label: use.action; anchors.verticalCenter: parent.verticalCenter; onClicked: use.act() }
        }
    }

    Use { icon: "mic"; tint: "#ff9f0a"; title: "Microphone"; apps: Privacy.micApps; action: Privacy.micMuted ? "Unmute" : "Mute"; onAct: Privacy.toggleMic() }
    Use { icon: "videocam"; tint: "#30d158"; title: "Camera"; apps: Privacy.cameraApps }
    Use { icon: "screen-share"; tint: "#bf5af2"; title: "Screen"; apps: Privacy.screenApps; action: "Stop"; onAct: { Privacy.stopSharing(); UiState.closePanel(); } }
    Label { visible: !Privacy.any; text: "Nothing is using the microphone, camera or screen"; role: "dim" }
}
