import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { load, eq, ok, root } from "./lib.mjs";
const P = load("settings-panes.js");

// One list, ids unique, 25 sections in the agreed order of groups.
const ids = P.panes.map(p => p.id);
eq(new Set(ids).size, ids.length, "ids unique");
eq(P.panes.length, 25, "25 sections");
eq(P.panes.filter(p => p.group === "Personal").length, 5, "Personal: 5");
eq(P.panes.filter(p => p.group === "Desktop").length, 9, "Desktop: 9");
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
eq(P.find("autostart", 3)[0].id, "autostart", "autostart has its own section");
eq(P.find("startup", 3)[0].id, "autostart", "startup apps in Autostart");
eq(P.find("browser", 3)[0].id, "apps", "the default browser in Applications");
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

// The tint's second hue lives in Appearance: by a word (Spotlight) and by the key's label (the app).
for (const q of ["tint", "dichroic", "hue", "second colour"]) eq(P.find(q, 3)[0].id, "appearance", `${q} → Appearance`);
eq(P.matches(P.panes.find(p => p.id === "appearance"), "second hue", ["look.dichroic.shift"], () => "Second hue"), true, "the Second hue row → Appearance");

// The Steam theme lives with the games in Power & performance: by a word
// (Spotlight), by its keys (the app's search), and its rows are in PowerPane.
for (const q of ["steam", "millennium", "steam theme"]) eq(P.find(q, 3)[0].id, "power", `${q} → Power & performance`);
const power = P.panes.find(p => p.id === "power");
for (const k of ["steam.theme.enabled", "steam.theme.sync"]) {
    ok(power.keys.some(pre => k === pre || k.startsWith(pre + ".")), `${k} under Power's keys`);
    ok(readFileSync(join(root, "apps/settings/panes/PowerPane.qml"), "utf8").includes(`key: "${k}"`), `${k} has a row in PowerPane`);
}
eq(P.matches(power, "follow vitrum", ["steam.theme.sync"], () => "Follow vitrum's colours"), true, "the Follow colours row → Power & performance");
ok(!readFileSync(join(root, "apps/settings/panes/PowerPane.qml"), "utf8").includes("steam.theme.opacity"), "no Panel opacity row: Steam's panels have fixed alphas");

// The Vesktop theme lives in Appearance, after the toolkit colouring: by a
// word (Spotlight), by its keys (the app's search), and its rows are in
// AppearancePane. There is no opacity: Vesktop gets the look, not glass.
for (const q of ["vesktop", "discord", "vencord", "vesktop theme"]) eq(P.find(q, 3)[0].id, "appearance", `${q} → Appearance`);
const appearance = P.panes.find(p => p.id === "appearance");
const appearanceQml = readFileSync(join(root, "apps/settings/panes/AppearancePane.qml"), "utf8");
for (const k of ["vesktop.theme.enabled", "vesktop.theme.sync"]) {
    ok(appearance.keys.some(pre => k === pre || k.startsWith(pre + ".")), `${k} under Appearance's keys`);
    ok(appearanceQml.includes(`key: "${k}"`), `${k} has a row in AppearancePane`);
}
ok(!appearanceQml.includes("vesktop.theme.opacity"), "no Vesktop opacity row");
ok(appearanceQml.indexOf('title: "Vesktop theme"') > appearanceQml.indexOf('key: "toolkits.gtk"'), "the Vesktop section after the toolkit rows");
eq(P.matches(appearance, "follow vitrum", ["vesktop.theme.sync"], () => "Follow vitrum's colours"), true, "the sync row → Appearance");
eq(P.matches(power, "vesktop", ["vesktop.theme.sync"], () => "Follow vitrum's colours"), false, "not Power's");
