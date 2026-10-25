.pragma library
// UI icon lookup: one name, a Phosphor glyph (the same codepoint in Phosphor
// Light and Phosphor Fill) and optionally a Nerd Font glyph. The mono preset
// prefers Nerd glyphs; anything missing falls back to Phosphor, and an unknown
// name to Phosphor's question mark, so no empty square ever shows.

var QUESTION = "";

function glyph(map, name, preset) {
    var e = map && map[name];
    if (!e) return { font: "phosphor", text: QUESTION };
    if (preset === "mono" && e.nerd) return { font: "nerd", text: e.nerd };
    return { font: "phosphor", text: e.phosphor || QUESTION };
}
