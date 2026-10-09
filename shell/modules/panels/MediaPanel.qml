import QtQuick
import qs.services
import qs.theme
import qs.components

// Now playing (the bar's panel): the player card, and a switch when several play.
Column {
    id: root
    spacing: Tokens.gap
    width: Tokens.islandHeight * 12

    PlayerCard { width: root.width; height: implicitHeight }

    Row {
        visible: Media.players.length > 1
        spacing: Tokens.gap / 2
        Repeater {
            model: Media.players
            Capsule { required property var modelData; label: modelData.identity; active: modelData === Media.current; onClicked: Media.setPlayer(modelData) }
        }
    }
    // Position updates while visible.
    Timer { interval: 1000; running: Media.playing; repeat: true; onTriggered: if (Media.current) Media.current.positionChanged() }
}
