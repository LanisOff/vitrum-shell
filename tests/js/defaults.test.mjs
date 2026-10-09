import { load, eq, ok, readJson } from "./lib.mjs";
const s = load("settings.js");
const defaults = readJson("shell/data/settings.defaults.json");
const enums = readJson("shell/data/settings.enums.json");
for (const path of Object.keys(enums)) {
  if (path.endsWith(".*")) {
    const parent = s.get(defaults, path.slice(0, -2), undefined);
    ok(parent !== undefined && typeof parent === "object", `${path}: parent map exists in defaults`);
    continue;
  }
  const v = s.get(defaults, path, undefined);
  ok(v !== undefined, `${path} exists in defaults`);
  ok(enums[path].indexOf(v) >= 0, `${path} default ${JSON.stringify(v)} is allowed`);
}
eq(s.validate(defaults, defaults, enums).warnings.length, 0, "defaults validate cleanly");
// the default bar layout uses only known modules
const bar = load("bar.js");
eq(bar.parseLayout(defaults.bar.layout).warnings.length, 0, "default bar layout is valid");
// palette presets named in enums all exist
const pal = readJson("shell/data/palettes.json");
for (const p of enums["palette.preset"]) ok(pal[p], `palette ${p} exists`);
