import QtQuick
import qs.services
import qs.theme
import qs.components

// The player on the desktop: the widget's own header, then the same card as
// the bar's media panel without its plate (the widget's glass is the card).
// With nothing playing, a quiet note instead of an empty frame.
Item {
    id: root
    property var options: ({})
    WidgetHeader { id: head; icon: "music"; title: "Now playing"; trailing: Media.available ? Media.identity : ""; hue: 270 }
    PlayerCard {
        anchors { fill: parent; topMargin: head.height + Tokens.gap * 0.5 }
        fill: true
        bare: true
        visible: Media.available
    }
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: head.height / 2
        visible: !Media.available
        spacing: Tokens.gap
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Tokens.islandHeight * 1.8; height: width; radius: width / 2
            color: Colors.alpha(Colors.accent, 0.16)
            Icon { anchors.centerIn: parent; name: "music"; size: parent.width * 0.5; filled: true; color: Colors.accent }
        }
        Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Nothing playing"; font.weight: Font.DemiBold }
        Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Music and videos show up here"; role: "dim"; size: Tokens.textSmall }
    }
    Timer { interval: 1000; running: Media.playing; repeat: true; onTriggered: if (Media.current) Media.current.positionChanged() }
}
