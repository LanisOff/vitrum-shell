import QtQuick
import qs.services
import qs.theme
import qs.components

/*
 * Now playing, on the lock screen: the same card as the bar's player
 * (PlayerCard: the blurred cover feathered into a rounded plate, the sharp
 * cover, wave, lyrics, spectrum) on the lock material. Shown only while a
 * player has something (lock.player); slides up into place.
 */
Item {
    id: card
    /// 0 → 1: the entrance (from LockView), times whether there is anything.
    property real appear: 1
    readonly property bool wanted: Settings.get("lock.player", true) && Media.available && (Media.title.length > 0 || Media.identity.length > 0)
    property real here: wanted ? 1 : 0
    Behavior on here { enabled: Motion.enabled; NumberAnimation { duration: Motion.emphasized; easing.type: Easing.OutCubic } }

    width: Tokens.islandHeight * 13
    // The card's own plate sits inside the lock's, corners concentric.
    readonly property real inset: Math.max(4, Tokens.radiusPanel - Tokens.radiusInner * 1.5)
    height: player.implicitHeight + 2 * inset
    visible: here * appear > 0.01
    opacity: here * appear
    transform: Translate { y: (1 - card.here * card.appear) * Tokens.islandHeight }

    Surface {
        anchors.fill: parent
        group: "lock"
        radius: Tokens.radiusPanel
    }

    // Its own plate (not bare): a blurred cover wash clipped by the Surface's
    // box had square corners poking out of the rounded card.
    PlayerCard {
        id: player
        x: card.inset; y: card.inset
        width: card.width - 2 * card.inset
        height: implicitHeight
    }

    // The position only updates when asked.
    Timer { interval: 1000; running: card.visible && Media.playing; repeat: true; onTriggered: if (Media.current) Media.current.positionChanged() }
}
