import { load, eq } from "./lib.mjs";
const k = load("keybinds.js");

// keyCaps: niri's key names → the caps drawn on screen
eq(k.keyCaps("Mod+Shift+Slash").join(" "), "Super Shift /", "modifiers and a symbol");
eq(k.keyCaps("Mod+Period").join(" "), "Super .", "period");
eq(k.keyCaps("Alt+Tab").join(" "), "Alt Tab", "plain names stay");
eq(k.keyCaps("Mod+Ctrl+Left").join(" "), "Super Ctrl ←", "arrows");
eq(k.keyCaps("XF86AudioRaiseVolume").join(" "), "Volume +", "media key");
eq(k.keyCaps("Mod+WheelScrollDown").join(" "), "Super Wheel ↓", "wheel");
eq(k.keyCaps("Print").join(" "), "Print", "single key");
eq(k.keyCaps("Mod+q").join(" "), "Super Q", "letters upper-case");
eq(k.keyCaps("").length, 0, "nothing");

const binds = [
  { section: "Desktop", keys: "Mod+Space", title: "Launcher" },
  { section: "Desktop", keys: "Mod+N", title: "Notification Centre" },
  { section: "Windows", keys: "Mod+Q", title: "Close window" },
  { section: "Windows", keys: "Mod+F", title: "Fullscreen" },
];
// group: sections in first-seen order, rows in file order
let g = k.group(binds, "");
eq(g.map(s => s.section).join(","), "Desktop,Windows", "sections in order");
eq(g[1].rows.map(r => r.title).join(","), "Close window,Fullscreen", "rows in order");
// search by title words, case-insensitive
g = k.group(binds, "notif");
eq(g.length, 1, "only the matching section");
eq(g[0].rows[0].title, "Notification Centre", "matched by title");
// search by key: "super q" finds Mod+Q
g = k.group(binds, "super q");
eq(g.length === 1 && g[0].rows.length === 1 && g[0].rows[0].title, "Close window", "matched by keys");
// search by section name
eq(k.group(binds, "windows")[0].rows.length, 2, "matched by section");
eq(k.group(binds, "zzz").length, 0, "no match");
eq(k.group(null, "").length, 0, "no binds file yet");

// A sequence (tmux: the prefix, then a key) is chords separated by spaces.
eq(k.keyCaps("Ctrl+a |").join(" "), "Ctrl A › |", "prefix then key");
eq(k.keyCaps("Ctrl+a Shift+f").join(" "), "Ctrl A › Shift F", "a capital is Shift");
eq(k.keyCaps("Ctrl+b \"").join(" "), "Ctrl B › \"", "a quote");
// search across a sequence: "ctrl a" finds the tmux prefix binds
eq(k.group([{ section: "tmux", keys: "Ctrl+a |", title: "Split side by side" }], "ctrl a |")[0].rows.length, 1, "sequence search");

// The same action on two keys (arrows and HJKL) is one row with both.
const dup = [
  { section: "Focus", keys: "Mod+Left", title: "Focus column left" },
  { section: "Focus", keys: "Mod+H", title: "Focus column left" },
  { section: "Focus", keys: "Mod+Right", title: "Focus column right" },
];
let gd = k.group(dup, "");
eq(gd[0].rows.length, 2, "duplicates merged");
eq(gd[0].rows[0].alts.map(a => a.join(" ")).join(" | "), "Super ← | Super H", "both key sets kept");
eq(k.group(dup, "super h")[0].rows[0].alts.length, 2, "a match on one alternative shows the row whole");

// overrides.kdl: the user's own binds, read live.
const kdl = `// mine
binds {
    Mod+P hotkey-overlay-title="Session menu" { spawn "vitrum-ipc" "session" "toggle"; }
    Mod+Q repeat=false { close-window; }
    Mod+Ctrl+T { spawn "kitty" "-e" "btop"; }
    Mod+Shift+E hotkey-overlay-title=null { quit; }
    // Mod+Z { spawn "nope"; }
}`;
const own = k.parseKdlBinds(kdl);
eq(own.length, 3, "three binds (a hidden one and a comment skipped)");
eq(own[0].keys + " = " + own[0].title, "Mod+P = Session menu", "title from hotkey-overlay-title");
eq(own[1].title, "Close window", "title from the action");
eq(own[2].title, "kitty -e btop", "title from a spawn");
eq(k.parseKdlBinds("").length, 0, "empty file");
eq(k.parseKdlBinds("binds {\n  Mod+Space { toggle-overview; }\n}")[0].title, "Toggle overview", "two-space indent");

// merge: the user's bind on an existing key takes its row; new keys go to "Your binds".
const base = [{ section: "Windows", keys: "Mod+Q", title: "Close window (vitrum)" }, { section: "Desktop", keys: "Mod+N", title: "Notifications" }];
const merged = k.mergeBinds(base, own);
eq(merged.filter(b => b.keys === "Mod+Q").length, 1, "one Mod+Q");
eq(merged.find(b => b.keys === "Mod+Q").section, "Windows", "kept its section");
eq(merged.find(b => b.keys === "Mod+Q").title, "Close window", "with the user's action");
eq(merged.filter(b => b.section === "Your binds").map(b => b.keys).join(","), "Mod+P,Mod+Ctrl+T", "new ones in Your binds");
eq(k.mergeBinds(base, []).length, 2, "nothing of the user's");
eq(merged.find(b => b.keys.toLowerCase() === "mod+n").title, "Notifications", "others untouched");

// hidden catalogue entries (niri's own overlay) are never listed
{
  const withHidden = [{ section: "niri", keys: "Mod+Shift+Slash", title: "Hotkey overlay", hidden: true },
                      { section: "Desktop", keys: "Mod+Space", title: "Launcher" }];
  eq(k.group(withHidden, "").map(s => s.section).join(","), "Desktop", "group skips hidden");
  eq(k.mergeBinds(withHidden, []).length, 1, "mergeBinds skips hidden");
}
// effective: changes and own binds over the catalogue
{
  const cat = [{ section: "niri", keys: "Mod+Shift+Slash", title: "Overlay", hidden: true },
               { section: "Desktop", keys: "Mod+Space", title: "Launcher" },
               { section: "Desktop", keys: "Mod+N", title: "Notification Centre" },
               { section: "Windows", keys: "Mod+Q", title: "Close window" }];
  const e = k.effective(cat, { "Mod+Space": "Mod+Alt+Space", "Mod+N": null, "Mod+Gone": "Mod+G" },
                        [{ keys: "Mod+Shift+B", command: "firefox", title: "Firefox" }]);
  eq(e.length, 4, "hidden left out, own added");
  eq(e[0].keys + "|" + e[0].default + "|" + e[0].changed, "Mod+Alt+Space|Mod+Space|true", "rebound");
  eq(e[1].off + "|" + e[1].keys, "true|", "turned off");
  eq(e[2].changed, false, "untouched");
  eq(e[3].section + "|" + e[3].own + "|" + e[3].title, "Your binds|0|Firefox", "own bind");
  // conflict
  eq(k.conflict(e, "mod+q", "Mod+Space", -1).title, "Close window", "held by a vitrum bind");
  eq(k.conflict(e, "Mod+Shift+B", "Mod+Space", -1).title, "Firefox", "held by an own bind");
  eq(k.conflict(e, "Mod+Alt+Space", "Mod+Space", -1), null, "its own keys are no conflict");
  eq(k.conflict(e, "Mod+N", "Mod+Space", -1), null, "a turned-off bind frees its keys");
  eq(k.conflict(e, "Mod+Shift+B", "", 0), null, "editing the own bind itself");
  eq(k.conflict(e, "Mod+Z", "Mod+Space", -1), null, "free keys");
}
// keyName / combo: Qt key events → niri names, layout-independent for the main block
{
  eq(k.keyName(0x54, "t", 0), "T", "letter");
  eq(k.keyName(0x422, "е", 28), "T", "Cyrillic layout: scan code (xkb 28 = KEY_T+8)");
  eq(k.keyName(0x2f, "/", 0), "Slash", "punctuation");
  eq(k.keyName(0x31, "1", 0), "1", "digit");
  eq(k.keyName(0x01000012, "", 0), "Left", "arrow");
  eq(k.keyName(0x01000004, "\r", 0), "Return", "enter");
  eq(k.keyName(0x01000030 + 4, "", 0), "F5", "function key");
  eq(k.keyName(0x20, " ", 0), "Space", "space");
  eq(k.keyName(0x01000020, "", 0), "", "Shift alone is not a key");
  eq(k.keyName(0x01000022, "", 0), "", "Meta alone is not a key");
  eq(k.combo({ super: true, shift: true, ctrl: true }, "T"), "Mod+Ctrl+Shift+T", "modifier order");
  eq(k.combo({}, "Print"), "Print", "no modifiers");
}
