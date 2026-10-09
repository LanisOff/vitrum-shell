import QtQuick
import qs.services
import qs.theme
import qs.components
import "../../../lib/text.js" as TextLib
import ".."

/*
 * The centre island: the clock; while something plays or is paused, the
 * track and its controls (play is right there), and the time beside them; while hovered, the focused window's
 * title. The island springs to the new width; the old contents fade out
 * before the new ones fade in, so two never show over each other.
 */
BarModule {
    id: root
    panel: mode === "media" ? "media" : "calendar"
    property date now: new Date()
    readonly property bool h24: Settings.get("clock.h24", true)
    readonly property bool secs: Settings.get("clock.seconds", false)
    property bool showTitle: false
    readonly property string mode: (showTitle || UiState.debugHoverTitle) && Niri.focusedWindow ? "title" : Media.active ? "media" : "clock"

    // The island springs to this (one spring: the island's). Hovering only
    // ever widens it: an island that shrank under the pointer would lose the
    // hover, grow back, and flicker.
    readonly property real baseWidth: (Media.active ? media : clock).implicitWidth
    implicitWidth: mode === "title" ? Math.max(title.implicitWidth, baseWidth) : baseWidth

    Timer { interval: root.secs ? 1000 : 10000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }
    // Lyrics follow the position only while something shows them.
    readonly property bool wantsLyrics: Settings.get("media.lyricsInBar", false) && root.mode === "media"
    onWantsLyricsChanged: wantsLyrics ? Lyrics.subscribe() : Lyrics.unsubscribe()
    Component.onCompleted: if (wantsLyrics) Lyrics.subscribe()
    Component.onDestruction: if (wantsLyrics) Lyrics.unsubscribe()
    Timer { id: hoverDelay; interval: 400; onTriggered: root.showTitle = root.hovered }
    onHoveredChanged: { if (hovered) hoverDelay.restart(); else { hoverDelay.stop(); showTitle = false; } }

    // Out quickly; in after the other has gone.
    component Swap: SequentialAnimation {
        id: swap
        property real to: 0
        PauseAnimation { duration: swap.to > 0.5 ? Motion.fast : 0 }
        NumberAnimation { duration: Motion.fast; easing.type: swap.to > 0.5 ? Easing.OutCubic : Easing.InCubic }
    }

    Row {
        id: clock
        anchors.centerIn: parent
        spacing: Tokens.gap
        opacity: root.mode === "clock" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { id: clockFade; enabled: Motion.enabled; Swap { to: clockFade.targetValue } }
        readonly property var p: TextLib.clockParts(root.now, root.h24)
        Label { text: Qt.formatDate(root.now, "ddd d MMM"); role: "dim" }
        Label { text: clock.p.hh + ":" + clock.p.mm + (root.secs ? ":" + clock.p.ss : "") + (clock.p.ampm ? " " + clock.p.ampm : ""); numeric: true; font.weight: Font.DemiBold }
    }
    Row {
        id: media
        anchors.centerIn: parent
        spacing: Tokens.gap
        opacity: root.mode === "media" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { id: mediaFade; enabled: Motion.enabled; Swap { to: mediaFade.targetValue } }
        Icon { name: "music"; filled: true; color: Media.playing ? Colors.accent : Colors.textDim; anchors.verticalCenter: parent.verticalCenter }
        // The line being sung instead of the title, if asked for (media.lyricsInBar).
        Label {
            id: track
            readonly property bool sung: Settings.get("media.lyricsInBar", false) && Lyrics.state === "synced" && Lyrics.current.length > 0
            // Kept while the row fades out: a player that quits empties its track first.
            Binding on text {
                when: root.mode === "media"
                value: TextLib.elide(track.sung ? Lyrics.current : Media.title + (Media.artist ? " — " + Media.artist : ""), 42)
                restoreMode: Binding.RestoreNone
            }
            anchors.verticalCenter: parent.verticalCenter
        }
        MediaControls { small: true; size: Tokens.islandHeight * 0.78; anchors.verticalCenter: parent.verticalCenter }
        // The time stays in view while the player has the island.
        Rectangle { width: 1; height: Tokens.islandHeight * 0.45; color: Colors.alpha(Colors.text, 0.2); anchors.verticalCenter: parent.verticalCenter }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: clock.p.hh + ":" + clock.p.mm + (clock.p.ampm ? " " + clock.p.ampm : "")
            numeric: true; font.weight: Font.DemiBold
        }
    }
    Row {
        id: title
        anchors.centerIn: parent
        spacing: Tokens.gap
        opacity: root.mode === "title" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { id: titleFade; enabled: Motion.enabled; Swap { to: titleFade.targetValue } }
        Icon { name: "window"; color: Colors.textDim; anchors.verticalCenter: parent.verticalCenter }
        Label { text: TextLib.elide(Niri.focusedWindow ? Niri.focusedWindow.title : "", 60); anchors.verticalCenter: parent.verticalCenter }
    }
}
