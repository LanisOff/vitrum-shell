import { load, eq, readJson } from "./lib.mjs";
const u = load("settingsui.js");
const s = load("settings.js");
const j = JSON.stringify;

eq(u.label("dock.iconSize"), "Icon size", "camelCase → words");
eq(u.label("bar.position"), "Position", "last segment");
eq(u.label("wallpaper.live.pauseWhenCovered"), "Pause when covered", "deep key");
eq(u.label("weather.units"), "Units", "simple");

const enums = { "materials.groups.*": ["solid", "frosted", "glass"], "bar.position": ["top", "bottom"] };
eq(j(u.options(enums, "bar.position")), j(["top", "bottom"]), "exact");
eq(j(u.options(enums, "materials.groups.bar")), j(["solid", "frosted", "glass"]), "wildcard");
eq(j(u.options(enums, "dock.iconSize")), j([]), "none");

// Leaf keys: objects are walked, lists and empty objects are one key.
const d = { a: 1, b: { c: true, d: [1], e: {} }, f: { g: { h: "x" } } };
eq(j(u.leafKeys(d)), j(["a", "b.c", "b.d", "b.e", "f.g.h"]), "leaf keys");

// The Advanced pane: parse, then validate; nothing invalid is ever applied.
const defaults = readJson("shell/data/settings.defaults.json");
const allEnums = readJson("shell/data/settings.enums.json");
const v = raw => s.validate(raw, defaults, allEnums);
const good = u.checkRaw('{"density":"compact"}', v);
eq(good.ok, true, "valid JSON with known values");
eq(good.value.density, "compact", "value passed through");
const bad = u.checkRaw('{"density": "compact",}', v);
eq(bad.ok, false, "trailing comma");
eq(bad.errors.length > 0, true, "an error message");
const typed = u.checkRaw('{"density": 3}', v);
eq(typed.ok, true, "wrong type still applies the rest");
eq(typed.warnings.length > 0, true, "and warns");
eq(u.checkRaw("[1,2]", v).ok, false, "not an object");
eq(u.checkRaw("", v).ok, true, "empty means defaults");
