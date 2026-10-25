import QtQuick
import ".."
import qs.services
import qs.theme
import qs.components

// Activity: game mode is on — the game's name (or "Game mode" when it is on by
// hand). A click shows or hides MangoHud in the game; a right-click opens the
// Control Centre, where game mode is turned off.
BarModule {
    id: root
    shown: GameMode.active
    implicitWidth: row.implicitWidth
    onClicked: m => {
        if (m.button === Qt.LeftButton) GameMode.toggleHud();
        else if (m.button === Qt.RightButton) root.openPanel("control");
    }
    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.gap / 2
        Icon { name: "gamepad"; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
        Label {
            text: GameMode.game ? GameMode.game.title || GameMode.game.appId || "A game" : "Game mode"
            width: Math.min(implicitWidth, 180)
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
