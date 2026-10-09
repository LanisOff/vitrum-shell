.pragma library
// UI icon lookup: one name, a Material Symbols glyph and optionally a Nerd
// Font glyph. The mono preset prefers Nerd glyphs; anything missing falls back
// to Material Symbols so no empty square ever shows.

function glyph(map, name, preset) {
    var e = map && map[name];
    if (!e) return { font: "material", text: "help" };
    if (preset === "mono" && e.nerd) return { font: "nerd", text: e.nerd };
    return { font: "material", text: e.material || "help" };
}
