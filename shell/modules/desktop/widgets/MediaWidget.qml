import QtQuick
import qs.services
import qs.theme
import qs.components

/*
 * The player on the desktop (Media): the header with the player's name, then
 * the same card as the bar's media panel without its plate (the widget's
 * glass is the card). PlayerCard lays itself out for the height it is given:
 *   M   the cover beside the track and the controls, the progress wave
 *   L   as M, the times, a line of lyrics and the spectrum under it
 *   XL  as L, wider, three lines of lyrics when there is the height
 * options: lyrics (the synced lyrics), visualizer (the spectrum; the global
 * media.visualizer still turns it off everywhere).
 * The card is made only while something plays (it keeps Cava and Lyrics
 * running). In a gallery card with nothing playing, a still sample stands in.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "L"
    property bool preview: false
    signal optionsEdited(var options)

    readonly property bool sample: preview && !Media.available

    WidgetHeader {
        id: head
        icon: "music"; title: "Now playing"
        trailing: Media.available ? Media.identity : root.sample ? "Music" : ""
    }
    WidgetEmpty {
        visible: !Media.available && !root.preview
        icon: "music"
        text: "Nothing playing"
    }

    Loader {
        anchors { fill: parent; topMargin: head.height + Tokens.gap * 0.6 }
        active: Media.available
        sourceComponent: PlayerCard {
            fill: true
            bare: true
            showLyrics: root.options.lyrics !== false
            showVisualizer: root.options.visualizer !== false
        }
    }
    // Some players only report the position when asked.
    Timer { interval: 1000; running: Media.playing && !GameMode.active; repeat: true; onTriggered: if (Media.current) Media.current.positionChanged() }

    // ---- the sample: PlayerCard's layout, still.
    Item {
        id: still
        visible: root.sample
        anchors { fill: parent; topMargin: head.height + Tokens.gap * 0.6 }
        readonly property real cover: Math.min(Tokens.islandHeight * 4.4, Math.max(Tokens.islandHeight * 1.8, height * 0.4), height - wave.height - Tokens.gap * 0.6)
        Row {
            id: trackRow
            spacing: Tokens.gap * 1.5
            Rectangle {
                width: still.cover; height: width; radius: Tokens.radiusInner
                color: Colors.alpha(Colors.accent, Colors.dark ? 0.22 : 0.16)
                Icon { anchors.centerIn: parent; name: "music"; filled: true; size: Math.round(parent.width * 0.42); color: Colors.accent }
            }
            Column {
                width: still.width - still.cover - Tokens.gap * 1.5
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Label { width: parent.width; text: "Song title"; font.weight: Font.DemiBold }
                Label { width: parent.width; text: "Artist"; role: "dim" }
                Item { width: 1; height: Tokens.gap * 0.4 }
                Row {
                    spacing: Tokens.gap
                    Icon { name: "previous"; filled: true; size: Tokens.iconSize * 1.2; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle {
                        width: Tokens.islandHeight * 0.95; height: width; radius: width / 2
                        color: Colors.accent
                        Icon { anchors.centerIn: parent; name: "play"; filled: true; size: Tokens.iconSize * 1.2; color: Colors.onAccent }
                    }
                    Icon { name: "next"; filled: true; size: Tokens.iconSize * 1.2; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
        Meter {
            id: wave
            anchors { left: parent.left; right: parent.right; top: trackRow.bottom; topMargin: Tokens.gap * 0.8 }
            kind: "linear"
            thickness: 4
            value: 0.35
        }
    }
}
