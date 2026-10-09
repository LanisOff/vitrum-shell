.pragma library
// What a PipeWire node is, for the mixer and the privacy dots. Quickshell's
// isSink flipped meaning for streams (0.3: a playing app is a "sink", it takes
// the app's audio), so the media class decides; the flags only when it is
// not known yet.

/// → "playback" | "capture" | "sink" | "source" | ""
function kind(n) {
    if (!n) return "";
    var cls = String((n.properties || {})["media.class"] || "");
    if (cls) {
        if (cls === "Stream/Output/Audio") return "playback";
        if (cls === "Stream/Input/Audio") return "capture";
        if (/^Audio\/Sink/.test(cls)) return "sink";
        if (/^Audio\/Source/.test(cls)) return "source";
        return "";
    }
    if (n.isStream) return n.isSink ? "playback" : "capture";
    return n.isSink ? "sink" : "source";
}
