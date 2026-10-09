// Every key in settings.defaults.json has UI: it appears as key: "<path>" (or a
// key list entry) in some Settings pane. Lists and objects count as one key.
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { root, readJson, eq, load } from "./lib.mjs";
const u = load("settingsui.js");
const keys = u.leafKeys(readJson("shell/data/settings.defaults.json"));
const dir = join(root, "apps", "settings", "panes");
let src = "";
try { for (const f of readdirSync(dir)) if (f.endsWith(".qml")) src += readFileSync(join(dir, f), "utf8"); } catch (e) {}
for (const k of keys) {
  // A map of settings edited by building the key ("materials.groups." + name) counts too.
  const has = src.includes(`"${k}"`) || src.includes(`"${k.slice(0, k.lastIndexOf(".") + 1)}" +`);
  eq(has, true, `settings key ${k} has UI in apps/settings/panes`);
}
