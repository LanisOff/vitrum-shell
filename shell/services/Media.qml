pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

/*
 * Now Playing. Picks one player out of however many are running and sticks
 * with it: switching the menu bar's track title because Firefox started a
 * muted autoplay video is the classic failure here, so a player only becomes
 * active by playing, and only loses the slot when it stops existing.
 */
Singleton {
    id: root

    property var current: null

    readonly property bool available: current !== null
    readonly property bool playing: available && current.playbackState === MprisPlaybackState.Playing
    // Playing or paused: there is a track to come back to. Stopped is not.
    readonly property bool active: playing || (available && current.playbackState === MprisPlaybackState.Paused)
    readonly property string title: available ? (current.trackTitle || "") : ""
    readonly property string artist: available ? (current.trackArtist || "") : ""
    readonly property string album: available ? (current.trackAlbum || "") : ""
    // The cover, held for the whole track. Browsers (Zen/Firefox on Yandex
    // Music) send it and clear it again half a second later as the page
    // updates its metadata; a new track without one clears it. Settled a beat
    // later, so a title that changes before the art does not keep the old one.
    readonly property string liveArt: available ? (current.trackArtUrl || "") : ""
    readonly property string trackKey: available ? [current.identity, title, artist].join("\n") : ""
    property string artUrl: ""
    property string _artKey: ""
    onLiveArtChanged: Qt.callLater(_settleArt)
    onTrackKeyChanged: Qt.callLater(_settleArt)
    function _settleArt() {
        if (liveArt) { artUrl = liveArt; _artKey = trackKey; }
        else if (trackKey !== _artKey) { artUrl = ""; _artKey = ""; }
    }
    readonly property string identity: available ? (current.identity || "") : ""
    readonly property real position: available && current.positionSupported ? current.position : 0
    readonly property real length: available ? current.length : 0

    readonly property string label: {
        if (!available) return "";
        if (artist && title) return artist + " — " + title;
        return title || identity;
    }

    readonly property var players: Mpris.players.values

    function _pick() {
        const list = Mpris.players.values;
        if (list.length === 0) { current = null; return; }
        // Keep the current one if it is still around and still playing.
        if (current && list.indexOf(current) >= 0
            && current.playbackState === MprisPlaybackState.Playing) return;

        const playingOne = list.find(p => p.playbackState === MprisPlaybackState.Playing);
        if (playingOne) { current = playingOne; return; }
        if (current && list.indexOf(current) >= 0) return;   // paused but still ours
        current = list[0];
    }

    Connections {
        target: Mpris.players
        function onValuesChanged() { root._pick(); }
    }

    Timer {
        // Playback state changes do not always emit through the list, so a
        // slow tick keeps the choice honest without costing anything.
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root._pick()
    }

    // ----------------------------------------------------------- actions ---

    function playPause() { if (available && current.canTogglePlaying) current.togglePlaying(); }
    function next()      { if (available && current.canGoNext) current.next(); }
    function previous()  { if (available && current.canGoPrevious) current.previous(); }
    function stop()      { if (available) current.stop(); }
    function seek(pos)   { if (available && current.canSeek) current.position = pos; }

    function setPlayer(p) { current = p; }
}
