import { existsSync } from "node:fs";
import { join } from "node:path";
import { load, eq, ok, root } from "./lib.mjs";
const P = load("settings-panes.js");

// One list, ids unique, 23 sections in the agreed order of groups.
const ids = P.panes.map(p => p.id);
eq(new Set(ids).size, ids.length, "ids unique");
eq(P.panes.length, 23, "23 sections");
eq(P.panes.filter(p => p.group === "Personal").length, 5, "Personal: 5");
eq(P.panes.filter(p => p.group === "Desktop").length, 7, "Desktop: 7");
eq(P.panes.filter(p => p.group === "System").length, 11, "System: 11");

// Old ids still open; unknown ones fall back to Appearance.
eq(P.resolve("search"), "navigation", "search → navigation");
eq(P.resolve("power"), "power", "power stays");
eq(P.resolve("lock"), "lock", "lock is its own");
eq(P.resolve("nope"), "appearance", "unknown → appearance");
eq(P.resolve(""), "appearance", "none → appearance");
eq(P.known("search"), true, "an alias is known");
eq(P.known("nope"), false, "unknown is not");

// Every section has its pane file.
for (const p of P.panes) ok(existsSync(join(root, "apps/settings", P.paneFile(p.id))), `pane file for ${p.id}`);
eq(P.paneFile("navigation"), "panes/NavigationPane.qml", "file name");

// Spotlight: by name, by a word, never on one letter.
eq(P.find("sound", 3)[0].id, "sound", "by name");
eq(P.find("wifi", 3)[0].id, "network", "by a word");
eq(P.find("lock", 3)[0].id, "lock", "lock screen lives in Lock & idle");
eq(P.find("brightness", 3)[0].id, "displays", "brightness in Displays");
eq(P.find("lyrics", 3)[0].id, "media", "lyrics in Media");
eq(P.find("hot corners", 3)[0].id, "navigation", "hot corners in Navigation");
eq(P.find("l", 3).length, 0, "one letter: none");

// The app's own search: the name, the section's words, or a setting's label.
const label = k => k.split(".").pop();
const keys = ["lock.idleMinutes", "media.lyrics", "corners.delay", "dock.magnify"];
const hit = (id, q) => P.matches(P.panes.find(p => p.id === id), q, keys, label);
eq(hit("displays", "brightness"), true, "brightness → Displays (a word)");
eq(hit("lock", "idle"), true, "idle → Lock & idle (name)");
eq(hit("lock", "lock after"), true, "lock after → Lock & idle (the spec's example)");
eq(hit("media", "lyrics"), true, "lyrics → Media");
eq(hit("navigation", "hot corners"), true, "hot corners → Navigation");
eq(hit("dock", "magnify"), true, "a setting's label");
eq(hit("dock", "lyrics"), false, "not another section's setting");
eq(hit("dock", ""), true, "empty query: everything");
eq(P.find("mouse")[0].id, "input", "mouse → Mouse & touchpad");
eq(P.find("sensitivity")[0].id, "input", "sensitivity → Mouse & touchpad");
eq(P.panes.findIndex(x => x.id === "input"), P.panes.findIndex(x => x.id === "keyboard") + 1, "right after Keyboard");
