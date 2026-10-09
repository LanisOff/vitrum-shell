import { load, eq } from "./lib.mjs";
const s = load("settings.js");
const d = { density: "compact", bar: { position: "top", minimap: false }, list: [1] };
const enums = { density: ["compact", "regular", "comfortable"], "bar.position": ["top", "bottom"] };
const r = s.validate({ density: 3, bar: { position: "left", minimap: true }, extra: 1, list: "x" }, d, enums);
eq(JSON.stringify(r.value), JSON.stringify({ bar: { minimap: true }, extra: 1 }), "bad keys dropped");
eq(r.warnings.length, 3, "three warnings (density type, bar.position enum, list type)");
eq(JSON.stringify(s.deepMerge({ a: { b: 1, c: [1] } }, { a: { c: [2] } })), JSON.stringify({ a: { b: 1, c: [2] } }), "arrays replaced");
eq(s.get({ a: { b: { c: 5 } } }, "a.b.c", 0), 5, "get deep");
eq(s.get({ a: {} }, "a.x.y", 7), 7, "get fallback");
eq(JSON.stringify(s.set({ a: { b: 1 } }, "a.c.d", 2)), JSON.stringify({ a: { b: 1, c: { d: 2 } } }), "set creates path");
// objects whose default is {} accept any object (free-form maps like materials.groups)
eq(JSON.stringify(s.validate({ m: { bar: "glass" } }, { m: {} }, {}).value), JSON.stringify({ m: { bar: "glass" } }), "free-form map");
// enum with wildcard child: materials.groups.* must be a material
const r2 = s.validate({ g: { bar: "chrome" , dock: "glass"} }, { g: {} }, { "g.*": ["solid", "frosted", "glass"] });
eq(JSON.stringify(r2.value), JSON.stringify({ g: { dock: "glass" } }), "wildcard enum");
