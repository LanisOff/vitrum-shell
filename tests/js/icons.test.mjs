import { load, eq } from "./lib.mjs";
const i = load("icons.js");
const map = { wifi: { phosphor: "", nerd: "\u{f05a9}" }, cpu: { phosphor: "" }, bare: {} };
eq(JSON.stringify(i.glyph(map, "wifi", "sans")), JSON.stringify({ font: "phosphor", text: "" }), "sans → phosphor");
eq(JSON.stringify(i.glyph(map, "wifi", "mono")), JSON.stringify({ font: "nerd", text: "\u{f05a9}" }), "mono → nerd");
eq(JSON.stringify(i.glyph(map, "cpu", "mono")), JSON.stringify({ font: "phosphor", text: "" }), "mono without nerd → phosphor");
eq(JSON.stringify(i.glyph(map, "nope", "sans")), JSON.stringify({ font: "phosphor", text: "" }), "unknown → Phosphor's question mark");
eq(JSON.stringify(i.glyph(map, "bare", "sans")), JSON.stringify({ font: "phosphor", text: "" }), "no glyph → question mark, never empty");
eq(JSON.stringify(i.glyph({}, "nope", "mono")), JSON.stringify({ font: "phosphor", text: "" }), "an empty map (not loaded yet) → question mark");

// Every icon name used in the shell and the apps exists in shell/data/icons.json:
// Icons.glyph("…"), icon: "…" (and the strings a ternary there picks), and an
// Icon or WeatherGlyph's name.
import { readFileSync, readdirSync, lstatSync } from "node:fs";
import { join } from "node:path";
import { root, readJson } from "./lib.mjs";
const real = readJson("shell/data/icons.json");
// apps/settings links to shell/components and the like; links are not followed.
function walk(d) { return readdirSync(d).flatMap(f => { const p = join(d, f); const s = lstatSync(p); return s.isSymbolicLink() ? [] : s.isDirectory() ? walk(p) : /\.(qml|js)$/.test(p) ? [p] : []; }); }
const picked = seg => [...seg.matchAll(/[?:]\s*"([a-z][a-z0-9-]*)"/g)].map(m => m[1]);
const used = new Map();
const use = (name, f) => { if (!used.has(name)) used.set(name, f); };
for (const f of [...walk(join(root, "shell")), ...walk(join(root, "apps"))]) {
  const src = readFileSync(f, "utf8");
  for (const m of src.matchAll(/Icons\.glyph\("([a-z][a-z0-9-]*)"/g)) use(m[1], f);
  for (const m of src.matchAll(/\b(?:icon|iconName|trailingIcon)\s*(:[^;,}\n]*)/g)) for (const n of picked(m[1])) use(n, f);
  for (const m of src.matchAll(/\b(?:Icon|WeatherGlyph)\s*\{[^{}]*?\bname\s*(:[^;}\n]*)/g)) for (const n of picked(m[1])) use(n, f);
}
eq(used.size > 100, true, "the scan finds the icon names in use");
for (const [name, f] of used) eq(!!real[name], true, `icon "${name}" (${f.slice(root.length + 1)}) is in icons.json`);

// Each entry has one Phosphor glyph from the font's private-use area (the same
// codepoint in Light and Fill), and the Phosphor icon's name for people.
for (const [name, e] of Object.entries(real)) {
  eq(typeof e.phosphor === "string" && [...e.phosphor].length === 1 && e.phosphor.codePointAt(0) >= 0xe000 && e.phosphor.codePointAt(0) <= 0xf8ff, true, `${name} has a Phosphor glyph`);
  eq(typeof e.ph === "string" && /^[a-z0-9-]+$/.test(e.ph), true, `${name} names its Phosphor icon`);
  eq("material" in e, false, `${name} has no Material Symbols ligature left`);
}
// Weather names get Phosphor's weather icons.
const weather = { "weather-clear": "sun", "weather-night": "moon-stars", "weather-cloudy": "cloud", "weather-partly": "cloud-sun", "weather-partly-night": "cloud-moon", "weather-rain": "cloud-rain", "weather-snow": "cloud-snow", "weather-storm": "cloud-lightning", "weather-fog": "cloud-fog" };
for (const [name, ph] of Object.entries(weather)) eq(real[name] && real[name].ph, ph, `${name} → ${ph}`);
