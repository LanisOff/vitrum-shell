import QtQuick
import QtQuick.Effects
import qs.services
import qs.theme
import qs.components

/*
 * Now playing, on the lock screen: the same card as the bar's player
 * (PlayerCard: cover, wave, lyrics, spectrum) on the lock material. Shown only
 * while a player has something (lock.player); slides up into place. The
 * card's own background is the cover, blurred, cross-fading between tracks.
 */
Item {
    id: card
    /// 0 → 1: the entrance (from LockView), times whether there is anything.
    property real appear: 1
    readonly property bool wanted: Settings.get("lock.player", true) && Media.available && (Media.title.length > 0 || Media.identity.length > 0)
    property real here: wanted ? 1 : 0
    Behavior on here { enabled: Motion.enabled; NumberAnimation { duration: Motion.emphasized; easing.type: Easing.OutCubic } }

    width: Tokens.islandHeight * 13
    readonly property real pad: Tokens.padding * 1.2
    height: player.implicitHeight + 2 * pad
    visible: here * appear > 0.01
    opacity: here * appear
    transform: Translate { y: (1 - card.here * card.appear) * Tokens.islandHeight }

    // The cover, two layers deep, so a new track fades over the old one.
    property string artA: ""
    property string artB: ""
    property bool showB: false
    readonly property string art: Media.artUrl
    onArtChanged: {
        if (showB) artA = art; else artB = art;
        showB = !showB;
    }
    Component.onCompleted: artA = art

    Surface {
        id: bg
        anchors.fill: parent
        group: "lock"
        radius: Tokens.radiusPanel
        clip: true
        // The cover, blurred, as a wash of its colours.
        Item {
            anchors.fill: parent
            opacity: 0.35
            Image { id: washA; anchors.fill: parent; source: card.artA; fillMode: Image.PreserveAspectCrop; visible: false }
            Image { id: washB; anchors.fill: parent; source: card.artB; fillMode: Image.PreserveAspectCrop; visible: false }
            MultiEffect { anchors.fill: parent; source: washA; blurEnabled: true; blurMax: 64; blur: 1; saturation: 0.3; opacity: card.showB ? 0 : 1; visible: washA.status === Image.Ready
                Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.emphasized * 1.5 } } }
            MultiEffect { anchors.fill: parent; source: washB; blurEnabled: true; blurMax: 64; blur: 1; saturation: 0.3; opacity: card.showB ? 1 : 0; visible: washB.status === Image.Ready
                Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.emphasized * 1.5 } } }
        }
    }

    PlayerCard {
        id: player
        bare: true
        x: card.pad; y: card.pad
        width: card.width - 2 * card.pad
        height: implicitHeight
    }

    // The position only updates when asked.
    Timer { interval: 1000; running: card.visible && Media.playing; repeat: true; onTriggered: if (Media.current) Media.current.positionChanged() }
}
