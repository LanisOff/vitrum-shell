import { load, eq } from "./lib.mjs";
const d = load("dock.js");
const dock = { x: 700, y: 1000, w: 500, h: 64 };
eq(d.overlaps(dock, [{ x: 0, y: 40, w: 900, h: 950 }]), false, "tile ends above dock");
eq(d.overlaps(dock, [{ x: 0, y: 40, w: 900, h: 970 }]), true, "tile reaches into dock");
eq(d.overlaps(dock, [{ x: 1300, y: 40, w: 600, h: 1040 }]), false, "beside the dock");
eq(d.overlaps(dock, []), false, "no tiles");
eq(d.intellihideVisible({ hovered: false, overlapping: true, dragging: false, settingsMode: false }), false, "hidden when covered");
eq(d.intellihideVisible({ hovered: true, overlapping: true, dragging: false, settingsMode: false }), true, "hover reveals");
eq(d.intellihideVisible({ hovered: false, overlapping: false, dragging: false, settingsMode: false }), true, "free → visible");
// items(pinned, windows): pinned first in order, then running-not-pinned in first-seen order.
const wins = [
  { id: 1, appId: "kitty", focused: false }, { id: 2, appId: "org.telegram.desktop", focused: true },
  { id: 3, appId: "Kitty", focused: false }, { id: 4, appId: "zen", focused: false }
];
const it = d.items(["org.kde.dolphin", "kitty", "zen"], wins);
eq(it.map(x => x.appId).join(","), "org.kde.dolphin,kitty,zen,org.telegram.desktop", "order");
eq(it[1].windows.length, 2, "kitty gathers windows case-insensitively");
eq(it[0].windows.length, 0, "pinned but not running");
eq(it[3].pinned, false, "running-only is not pinned");
eq(it[3].focused, true, "focused flag");
