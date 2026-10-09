import { load, eq } from "./lib.mjs";
const i = load("icons.js");
const map = { wifi: { material: "wifi", nerd: "\u{f05a9}" }, cpu: { material: "memory" } };
eq(JSON.stringify(i.glyph(map, "wifi", "sans")), JSON.stringify({ font: "material", text: "wifi" }), "sans → material");
eq(JSON.stringify(i.glyph(map, "wifi", "mono")), JSON.stringify({ font: "nerd", text: "\u{f05a9}" }), "mono → nerd");
eq(JSON.stringify(i.glyph(map, "cpu", "mono")), JSON.stringify({ font: "material", text: "memory" }), "mono without nerd → material");
eq(JSON.stringify(i.glyph(map, "nope", "sans")), JSON.stringify({ font: "material", text: "help" }), "unknown → help");

// Every icon name used in the shell (Icons.glyph("…") or icon: "…") exists in shell/data/icons.json.
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { root, readJson } from "./lib.mjs";
const real = readJson("shell/data/icons.json");
function walk(d) { return readdirSync(d).flatMap(f => { const p = join(d, f); return statSync(p).isDirectory() ? walk(p) : p.endsWith(".qml") ? [p] : []; }); }
const used = new Set();
for (const f of walk(join(root, "shell"))) {
  const src = readFileSync(f, "utf8");
  for (const m of src.matchAll(/(?:Icons\.glyph\(|\bicon:\s*)"([a-z][a-z0-9-]*)"/g)) used.add(m[1]);
  for (const m of src.matchAll(/\bIcon\s*\{[^{}]*?\bname:\s*"([a-z][a-z0-9-]*)"/g)) used.add(m[1]);
}
for (const name of used) eq(!!real[name], true, `icon "${name}" is in icons.json`);
for (const [name, e] of Object.entries(real)) eq(typeof e.material, "string", `${name} has a material glyph`);
