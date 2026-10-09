import { load, eq, ok } from "./lib.mjs";
const b = load("bar.js");
const r = b.parseLayout({ left: [["workspaces", "bogus"]], center: [["context"]], right: [["cpu"], []] });
eq(JSON.stringify(r.layout), JSON.stringify({ left: [["workspaces"]], center: [["context"]], activities: [], right: [["cpu"]] }), "unknown and empty dropped");
eq(r.warnings.length, 1, "one warning for bogus");
const wins = [];
for (let i = 1; i <= 12; i++) wins.push({ id: i, workspaceId: 3, appId: "a" + i, focused: i === 6, layout: { pos_in_scrolling_layout: [i, 1], tile_size: [i === 2 ? 1800 : 900, 1000], tile_pos_in_workspace_view: (i >= 5 && i <= 6) ? [100, 0] : null } });
wins.push({ id: 99, workspaceId: 4, appId: "other", focused: false, layout: { pos_in_scrolling_layout: [1, 1], tile_size: [900, 1000] } });
const m = b.minimapColumns(wins, 3, 8);
eq(m.columns.length, 8, "capped at 8");
eq(m.columns.some(c => c.focused), true, "focused column kept in view");
eq(m.moreLeft + m.moreRight, 4, "overflow counted");
eq(m.columns.find(c => c.col === 2) ? m.columns.find(c => c.col === 2).widthFrac : 2, 2, "double-width column");

// Wrong shapes inside the layout: a bare module name is an island of one, anything
// else is dropped with a warning — never an exception that empties the bar.
{
  const r2 = b.parseLayout({ left: ["workspaces", 3, null], center: "context", right: [["cpu", 7]] });
  eq(JSON.stringify(r2.layout.left), JSON.stringify([["workspaces"]]), "bare name → island of one; junk dropped");
  eq(JSON.stringify(r2.layout.center), JSON.stringify([]), "a side that is not a list is empty");
  eq(JSON.stringify(r2.layout.right), JSON.stringify([["cpu"]]), "non-string module dropped");
  eq(r2.warnings.length >= 3, true, "warned");
}

// Activities: islands of their own, right of the centre.
{
  const r3 = b.parseLayout({ activities: [["sharing"], "recording"] });
  eq(JSON.stringify(r3.layout.activities), JSON.stringify([["sharing"], ["recording"]]), "activities parsed like any side");
}
// Every known module has its file.
{
  const { existsSync } = await import("node:fs");
  const { join } = await import("node:path");
  const { root } = await import("./lib.mjs");
  for (const m of b.modules()) ok(existsSync(join(root, "shell/modules/bar/modules", m + ".qml")), "module file for " + m);
}

// primaryScreen(screens, configured): the one asked for while it is there,
// else the top-left screen of the layout — not whichever the list names first.
{
  const s = [{ name: "DP-2", x: 1920, y: 0 }, { name: "HDMI-A-1", x: 0, y: 0 }];
  eq(b.primaryScreen(s, ""), "HDMI-A-1", "top-left, not the first listed");
  eq(b.primaryScreen(s, "DP-2"), "DP-2", "the configured one");
  eq(b.primaryScreen(s, "HDMI-A-9"), "HDMI-A-1", "a configured one that is gone: top-left");
  eq(b.primaryScreen([{ name: "A", x: 0, y: 1080 }, { name: "B", x: 0, y: 0 }], ""), "B", "above wins at the same x");
  eq(b.primaryScreen([], ""), "", "no screens");
}
