import { load, eq } from "./lib.mjs";
const p = load("pwnodes.js");

// Quickshell 0.3 flags a playback stream as a sink (it takes the app's audio)
// and a capture stream as a source: media.class says which, whatever the flags.
const node = (cls, isSink, isStream) => ({ isSink, isStream, properties: cls ? { "media.class": cls } : {} });

eq(p.kind(node("Stream/Output/Audio", true, true)), "playback", "an app playing (0.3 flags)");
eq(p.kind(node("Stream/Output/Audio", false, true)), "playback", "an app playing (older flags)");
eq(p.kind(node("Stream/Input/Audio", false, true)), "capture", "an app recording (0.3 flags)");
eq(p.kind(node("Stream/Input/Audio", true, true)), "capture", "an app recording (older flags)");
eq(p.kind(node("Audio/Sink", true, false)), "sink", "speakers");
eq(p.kind(node("Audio/Source", false, false)), "source", "a microphone");
eq(p.kind(node("Audio/Source/Virtual", false, false)), "source", "a virtual microphone");
eq(p.kind(node("Video/Source", false, false)), "", "not audio");
// No class known yet: the 0.3 flags.
eq(p.kind(node("", true, true)), "playback", "no class: a sink stream plays");
eq(p.kind(node("", false, true)), "capture", "no class: a source stream records");
eq(p.kind(node("", true, false)), "sink", "no class: a sink device");
eq(p.kind(null), "", "nothing");
