pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../lib/pwnodes.js" as Nodes

/*
 * Volume, mute, and the device lists the Sound pane needs.
 *
 * Pipewire is bound directly rather than shelling out to wpctl: the node
 * objects push changes, so the OSD appears the instant a volume key is pressed
 * rather than after a process round-trip.
 */
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool available: sink !== null

    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : true
    readonly property real micVolume: source && source.audio ? source.audio.volume : 0
    readonly property bool micMuted: source && source.audio ? source.audio.muted : true

    readonly property string sinkName: sink ? (sink.description || sink.nickname || sink.name || "") : ""
    readonly property string sourceName: source ? (source.description || source.nickname || source.name || "") : ""

    /// Emitted on any user-driven change, so the OSD knows to show itself.
    signal feedback(string kind)

    // Keeping the default nodes tracked is what makes their `audio` property
    // live; without this they report zero.
    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => n !== null)
    }

    // All sinks and sources, for the Sound pane's device pickers.
    readonly property var sinks: Pipewire.nodes.values.filter(
        n => n.isSink && n.isStream === false && n.audio)
    readonly property var sources: Pipewire.nodes.values.filter(
        n => !n.isSink && n.isStream === false && n.audio)
    /// Applications currently playing, for the per-app volume list.
    readonly property var streams: Pipewire.nodes.values.filter(
        n => Nodes.kind(n) === "playback" && n.audio)
    // Tracked so their volume and names are live (the mixer).
    PwObjectTracker { objects: root.streams }
    function streamName(n) {
        const p = (n && n.properties) || {};
        return p["application.name"] || p["application.process.binary"] || n.description || n.name || "An app";
    }
    function setStreamVolume(n, v) { if (n && n.audio) { n.audio.volume = Math.max(0, Math.min(1.5, v)); } }

    // ----------------------------------------------------------- actions ---

    function setVolume(v) {
        if (!sink || !sink.audio) return;
        sink.audio.volume = Math.max(0, Math.min(1.5, v));
        feedback("volume");
    }

    function step(delta) {
        if (!sink || !sink.audio) return;
        // macOS steps in sixteenths and un-mutes when you raise the volume.
        const next = Math.max(0, Math.min(1.0, sink.audio.volume + delta));
        sink.audio.volume = next;
        if (delta > 0 && sink.audio.muted) sink.audio.muted = false;
        feedback("volume");
    }

    function toggleMute() {
        if (!sink || !sink.audio) return;
        sink.audio.muted = !sink.audio.muted;
        feedback("volume");
    }

    function toggleMicMute() {
        if (!source || !source.audio) return;
        source.audio.muted = !source.audio.muted;
        feedback("mic");
    }

    function setMicVolume(v) {
        if (!source || !source.audio) return;
        source.audio.volume = Math.max(0, Math.min(1.0, v));
        feedback("mic");
    }

    function setDefaultSink(node) {
        if (node) Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultSource(node) {
        if (node) Pipewire.preferredDefaultAudioSource = node;
    }
}
