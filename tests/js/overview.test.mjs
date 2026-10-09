import { load, eq } from "./lib.mjs";
const o = load("overview.js");
const j = JSON.stringify;

// Windows in most-recently-used order, as Niri.windowsByRecency() gives them.
const wins = [
  { id: 1, appId: "kitty", title: "~/src", workspaceId: 10 },
  { id: 2, appId: "org.kde.dolphin", title: "Home — Dolphin", workspaceId: 11 },
  { id: 3, appId: "zen", title: "Kitty docs — Zen", workspaceId: 10 },
  { id: 4, appId: "kitty", title: "htop", workspaceId: 12 }
];
const names = { "org.kde.dolphin": "Dolphin", kitty: "kitty", zen: "Zen Browser" };

eq(j(o.filter(wins, "", names).map(w => w.id)), j([1, 2, 3, 4]), "empty query: everything, MRU order");
eq(j(o.filter(wins, "dolph", names).map(w => w.id)), j([2]), "by app id or name");
eq(j(o.filter(wins, "KITTY", names).map(w => w.id)), j([1, 4, 3]), "app matches before title matches, case-insensitive, MRU within");
eq(j(o.filter(wins, "htop", names).map(w => w.id)), j([4]), "by title");
eq(j(o.filter(wins, "browser", names).map(w => w.id)), j([3]), "by app name");
eq(j(o.filter(wins, "nothing", names)), j([]), "no match");
eq(j(o.filter(wins, "  zen ", names).map(w => w.id)), j([3]), "trimmed");

// The rail: one row per workspace on the output, its window count.
const spaces = [{ id: 10, idx: 1, name: "", active: true }, { id: 11, idx: 2, name: "web", active: false }, { id: 12, idx: 3, name: "", active: false }];
eq(j(o.rail(spaces, wins)), j([
  { id: 10, idx: 1, label: "1", count: 2, active: true },
  { id: 11, idx: 2, label: "2 · web", count: 1, active: false },
  { id: 12, idx: 3, label: "3", count: 1, active: false }
]), "rail rows");
