import { load, eq } from "./lib.mjs";
const k = load("keyboard.js");
const layouts = ["English (US)", "Russian"];
// Focus moves to an app: its last layout, if it had one and it is not already on.
eq(k.switchTo({ "org.telegram.desktop": "Russian" }, "org.telegram.desktop", layouts, 0), 1, "telegram was Russian");
eq(k.switchTo({ "org.telegram.desktop": "Russian" }, "org.telegram.desktop", layouts, 1), -1, "already Russian");
eq(k.switchTo({}, "kitty", layouts, 1), -1, "a new app keeps what is on");
eq(k.switchTo({ kitty: "German" }, "kitty", layouts, 0), -1, "a layout that is gone");
eq(k.switchTo({ kitty: "English (US)" }, "", layouts, 1), -1, "no app");
// What is remembered: the layout an app was left in.
eq(JSON.stringify(k.remember({ a: "Russian" }, "kitty", "English (US)")), JSON.stringify({ a: "Russian", kitty: "English (US)" }), "remembered");
eq(JSON.stringify(k.remember({ a: "Russian" }, "", "English (US)")), JSON.stringify({ a: "Russian" }), "nothing without an app");

// ---- layouts (Settings → Keyboard → Layouts)
const J = JSON.stringify;
eq(J(k.splitLayout("de(nodeadkeys)")), J({ layout: "de", variant: "nodeadkeys" }), "layout with a variant");
eq(J(k.splitLayout(" us ")), J({ layout: "us", variant: "" }), "a plain layout");
eq(k.splitLayout('us"; spawn'), null, "nothing that could break out of the KDL string");
eq(k.splitLayout(""), null, "empty");
// niri's config.kdl: the xkb block, comments ignored.
const cfg = `input {\n    keyboard {\n        // xkb { layout "fr" }\n        xkb {\n            layout "us,ru"\n            variant ",phonetic"\n            options "grp:alt_shift_toggle,compose:ralt"\n        }\n    }\n}\n`;
eq(J(k.parseXkb(cfg)), J({ layout: "us,ru", variant: ",phonetic", options: "grp:alt_shift_toggle,compose:ralt" }), "xkb block");
eq(k.parseXkb("input { }"), null, "no xkb");
eq(k.parseXkb('/* xkb { layout "fr" } */ input {}'), null, "a block comment is not config");
eq(J(k.xkbLayouts(k.parseXkb(cfg))), J(["us", "ru(phonetic)"]), "layouts and their variants");
eq(J(k.currentLayouts([], cfg)), J(["us", "ru(phonetic)"]), "nothing saved: config.kdl's");
eq(J(k.currentLayouts(["us", "de"], cfg)), J(["us", "de"]), "saved wins");
eq(J(k.currentLayouts(["us", "bad layout!", "us", "de", "fr", "it", "es"], cfg)), J(["us", "de", "fr", "it"]), "cleaned: valid, distinct, four at most");
eq(J(k.currentLayouts(undefined, "")), J([]), "nothing at all");
// The xkb catalogue.
const lst = "! model\n  pc105           Generic 105-key PC\n\n! layout\n  us              English (US)\n  de              German\n  ru              Russian\n\n! variant\n  nodeadkeys      de: German (no dead keys)\n  phonetic        ru: Russian (phonetic)\n\n! option\n  grp                  Switching to another layout\n";
const rules = k.parseRules(lst);
eq(J(rules.map(r => r.id)), J(["us", "de", "ru", "de(nodeadkeys)", "ru(phonetic)"]), "layouts then variants, no models or options");
eq(k.layoutName(rules, "de(nodeadkeys)"), "German (no dead keys)", "a variant's name");
eq(k.layoutName(rules, "xx"), "xx", "unknown: its id");
eq(J(k.searchLayouts(rules, "ger", [], 8).map(r => r.id)), J(["de", "de(nodeadkeys)"]), "search by name");
eq(J(k.searchLayouts(rules, "de", ["de"], 8).map(r => r.id)), J(["de(nodeadkeys)"]), "search by id, what is there left out");
eq(k.searchLayouts(rules, "", [], 8).length, 0, "no query, no list");
// Editing the list.
eq(J(k.addLayout(["us", "ru"], "de")), J(["us", "ru", "de"]), "add");
eq(J(k.addLayout(["us", "ru"], "ru")), J(["us", "ru"]), "no duplicates");
eq(J(k.addLayout(["us", "ru", "de", "fr"], "it")), J(["us", "ru", "de", "fr"]), "four at most");
eq(J(k.addLayout(["us"], "x y")), J(["us"]), "invalid is not added");
eq(J(k.removeLayout(["us", "ru", "de"], 2)), J(["us", "ru"]), "remove");
eq(J(k.removeLayout(["us"], 0)), J(["us"]), "the last one stays");
eq(J(k.moveLayout(["us", "ru", "de"], 2, -1)), J(["us", "de", "ru"]), "move up");
eq(J(k.moveLayout(["us", "ru", "de"], 0, -1)), J(["us", "ru", "de"]), "the first cannot go up");
// Short labels for the bar and the lock.
eq(k.shortName("English (US)"), "US", "country in brackets");
eq(k.shortName("German"), "DE", "German is DE, not GE");
eq(k.shortName("German (no dead keys)"), "DE", "a variant");
eq(k.shortName("Russian"), "RU", "Russian");
eq(k.shortName("Esperanto"), "ES", "unknown: two letters");
eq(k.shortName(""), "", "none");
eq(J(k.layoutsFromNames(rules, ["English (US)", "Russian (phonetic)", "Klingon"])), J(["us", "ru(phonetic)"]), "ids from niri's names");

// ---- input method (the input_method component: fcitx5 holds the layouts)
eq(k.fcitxIm("us"), "keyboard-us", "a keymap");
eq(k.fcitxIm("ru"), "keyboard-ru", "another keymap");
eq(k.fcitxIm("de(nodeadkeys)"), "keyboard-de-nodeadkeys", "a variant");
eq(k.fcitxIm("jp"), "mozc", "Japanese is the engine");
eq(k.fcitxIm("kr"), "hangul", "Korean is the engine");
eq(k.fcitxIm("cn"), "pinyin", "Chinese is the engine");
eq(k.fcitxIm("jp(kana)"), "keyboard-jp-kana", "a chosen variant stays a keymap");
eq(k.fcitxIm("nonsense!"), "", "not an entry");
eq(k.fcitxEntry("mozc"), "jp", "the engine's entry");
eq(k.fcitxEntry("keyboard-ru"), "ru", "a keymap's entry");
eq(k.fcitxEntry("keyboard-de-nodeadkeys"), "de(nodeadkeys)", "a variant's entry");
eq(k.fcitxEntry("rime"), "", "one vitrum did not add");
for (const e of ["us", "ru", "jp", "kr", "cn", "de(nodeadkeys)", "jp(kana)"])
  eq(k.fcitxEntry(k.fcitxIm(e)), e, "there and back: " + e);
eq(k.isEngine("jp"), true, "jp");
eq(k.isEngine("jp(kana)"), false, "kana is typed on a keymap");
eq(k.isEngine("us"), false, "us");
eq(k.wantsEngine(["us", "ru", "jp"]), true, "the case that started it");
eq(k.wantsEngine(["us", "ru"]), false, "no engine");
eq(k.wantsEngine("nope"), false, "no list");
eq(k.fcitxShort("keyboard-us", "English (US)"), "EN", "EN, not US");
eq(k.fcitxShort("keyboard-us-intl"), "EN", "a US variant");
eq(k.fcitxShort("keyboard-ru", "Russian"), "RU", "RU");
eq(k.fcitxShort("mozc"), "JP", "JP");
eq(k.fcitxShort("hangul"), "KR", "KR");
eq(k.fcitxShort("pinyin"), "CN", "CN");
eq(k.fcitxShort("keyboard-ua"), "UA", "no name: the layout");
eq(k.fcitxShort("rime"), "RI", "one vitrum did not add");
const held = ["keyboard-us", "keyboard-ru", "mozc", "hangul"];
eq(k.isKeymap("keyboard-ru"), true, "a keymap");
eq(k.isKeymap("mozc"), false, "an engine");
eq(k.isKeymap(""), false, "nothing");
eq(k.holdIm(held, "keyboard-ru", "keyboard-us"), "keyboard-ru", "RU stays for a Cyrillic password");
eq(k.holdIm(held, "mozc", "keyboard-ru"), "keyboard-ru", "an engine gives way to the last keymap");
eq(k.holdIm(held, "mozc", ""), "keyboard-us", "or the first keymap");
eq(k.holdIm(held, "mozc", "keyboard-de"), "keyboard-us", "a last keymap no longer listed");
eq(k.holdIm(["mozc", "keyboard-ru"], "mozc", ""), "keyboard-ru", "never an engine, whatever comes first");
eq(k.holdIm([], "mozc", ""), "", "no list");
eq(k.nextKeymap(held, "keyboard-us"), "keyboard-ru", "the next keymap");
eq(k.nextKeymap(held, "keyboard-ru"), "keyboard-us", "past the engines, round");
eq(k.nextKeymap(held, "keyboard-ru", false), "keyboard-us", "backwards");
eq(k.nextKeymap(held, "mozc"), "keyboard-us", "from an engine");
eq(k.nextKeymap(["keyboard-us", "mozc"], "keyboard-us"), "", "one keymap: nowhere to go");
eq(k.nextKeymap(["mozc"], "mozc"), "", "none at all");
const profile = "[Groups/0]\nName=Default\nDefault Layout=us\nDefaultIM=mozc\n\n[Groups/0/Items/1]\nName=keyboard-ru\nLayout=\n\n[Groups/0/Items/0]\nName=keyboard-us\nLayout=\n\n[Groups/0/Items/2]\nName=mozc\nLayout=\n\n[Groups/1/Items/0]\nName=hangul\n\n[GroupOrder]\n0=Default\n";
eq(J(k.parseProfile(profile)), J(["keyboard-us", "keyboard-ru", "mozc"]), "the first group's, in order");
eq(J(k.parseProfile("")), J([]), "no profile");
eq(J(k.cleanLayouts(["us", "ru", "jp", "kr", "cn"], k.MAX_FCITX)), J(["us", "ru", "jp", "kr", "cn"]), "fcitx5 holds five");
eq(J(k.addLayout(["us", "ru", "jp", "kr"], "cn", k.MAX_FCITX)), J(["us", "ru", "jp", "kr", "cn"]), "and adds a fifth");
eq(J(k.addLayout(["us", "ru", "jp", "kr"], "cn")), J(["us", "ru", "jp", "kr"]), "xkb still stops at four");
eq(J(k.moveLayout(["us", "ru", "jp", "kr", "cn"], 4, -1, k.MAX_FCITX)), J(["us", "ru", "jp", "cn", "kr"]), "move past four");
eq(J(k.removeLayout(["us", "ru", "jp", "kr", "cn"], 0, k.MAX_FCITX)), J(["ru", "jp", "kr", "cn"]), "remove past four");
