import { load, eq } from "./lib.mjs";
const w = load("widgets.js");
const j = JSON.stringify;
const screen = { w: 1920, h: 1080 };

// Positions snap to the grid step.
eq(w.snap(23, 8), 24, "rounds to the nearest step");
eq(w.snap(19, 8), 16, "down as well");
eq(w.snap(5, 0), 5, "no grid → unchanged");

// A rectangle stays on screen, at least the minimum size, snapped.
eq(j(w.place({ x: -50, y: 1070, w: 300, h: 200 }, screen, 8, { w: 120, h: 80 })), j({ x: 0, y: 880, w: 304, h: 200 }), "pushed back on screen");
eq(j(w.place({ x: 10, y: 10, w: 20, h: 20 }, screen, 8, { w: 120, h: 80 })), j({ x: 8, y: 8, w: 120, h: 80 }), "minimum size");
eq(j(w.place({ x: 10, y: 10, w: 5000, h: 20 }, screen, 8, { w: 120, h: 80 })), j({ x: 0, y: 8, w: 1920, h: 80 }), "no wider than the screen");

// Only this output's widgets.
const items = [{ id: "a", type: "clock", output: "DP-1" }, { id: "b", type: "notes", output: "HDMI-A-1" }];
eq(j(w.forOutput(items, "DP-1").map(i => i.id)), j(["a"]), "per output");
eq(j(w.forOutput(items, "eDP-1")), j([]), "none elsewhere");

// Updating returns a new list; the others are untouched.
const up = w.update(items, "a", { x: 40 });
eq(up[0].x, 40, "patched");
eq(items[0].x, undefined, "original unchanged");
eq(up[1], items[1], "others are the same objects");
eq(j(w.remove(items, "a").map(i => i.id)), j(["b"]), "remove");

// Adding: the type's default size, at the first free grid spot from the top left
// (below the bar margin), on that output; ids are unique.
const added = w.add([], "clock", "DP-1", screen, 8, 48, () => "id1");
eq(j(added[0]), j({ id: "id1", type: "clock", output: "DP-1", x: 32, y: 80, w: 320, h: 160, options: {} }), "first clock");
const two = w.add(added, "clock", "DP-1", screen, 8, 48, () => "id2");
eq(two[1].y > two[0].y + two[0].h - 1 || two[1].x >= two[0].x + two[0].w, true, "second does not overlap the first");
const other = w.add(added, "clock", "HDMI-A-1", screen, 8, 48, () => "id3");
eq(j({ x: other[1].x, y: other[1].y }), j({ x: 32, y: 80 }), "another output's widgets do not block");

// Interactive types take input outside edit mode; the rest let clicks through.
eq(w.interactive("notes"), true, "notes");
eq(w.interactive("media"), true, "media");
eq(w.interactive("shortcuts"), true, "shortcuts");
eq(w.interactive("clock"), false, "clock");

// Unknown types are dropped when loading settings, bad numbers fixed.
eq(j(w.sanitize([{ id: "x", type: "bogus", output: "DP-1" }, { type: "clock", output: "DP-1", x: "a" }], () => "n1")),
   j([{ id: "n1", type: "clock", output: "DP-1", x: 0, y: 0, w: 320, h: 160, options: {} }]), "sanitize");

// Month grid for the calendar widget: weeks start on Monday, 6 rows of 7.
const g = w.monthGrid(2026, 9, 1);   // October 2026 starts on a Thursday
eq(g.length, 42, "six weeks");
eq(j(g.slice(0, 4).map(d => [d.day, d.inMonth])), j([[28, false], [29, false], [30, false], [1, true]]), "leading days of September");
eq(g[3 + 30].day, 31, "last day of October");
eq(j(w.monthGrid(2026, 9, 0).slice(0, 5).map(d => d.day)), j([27, 28, 29, 30, 1]), "Sunday first");

// Keeping the widget list in place: only additions and removals touch the model,
// so a settings change does not recreate (and reset) every widget.
eq(j(w.syncPlan(["a", "b", "c"], ["a", "b", "c"])), j({ remove: [], add: [] }), "same ids → nothing");
eq(j(w.syncPlan(["a", "b", "c"], ["a", "c", "d"])), j({ remove: [1], add: ["d"] }), "one gone, one new");
eq(j(w.syncPlan(["a", "b", "c"], [])), j({ remove: [2, 1, 0], add: [] }), "removals from the end");
eq(j(w.syncPlan([], ["x", "y"])), j({ remove: [], add: ["x", "y"] }), "all new");

// Alignment to neighbours: within the threshold an edge lines up with another
// widget's edge, or sits one gap away from it; farther than that, nothing moves.
{
  const other = [{ x: 100, y: 100, w: 200, h: 100 }];
  const o = { threshold: 12, gap: 16 };
  eq(j(w.align({ x: 106, y: 300, w: 120, h: 80 }, other, "move", o)), j({ x: 100, y: 300, w: 120, h: 80 }), "left edges line up");
  eq(j(w.align({ x: 175, y: 300, w: 120, h: 80 }, other, "move", o)), j({ x: 180, y: 300, w: 120, h: 80 }), "right edges line up");
  eq(j(w.align({ x: 310, y: 108, w: 120, h: 80 }, other, "move", o)), j({ x: 316, y: 100, w: 120, h: 80 }), "beside it, one gap away, tops aligned");
  eq(j(w.align({ x: 100, y: 210, w: 200, h: 80 }, other, "move", o)), j({ x: 100, y: 216, w: 200, h: 80 }), "under it, one gap away");
  eq(j(w.align({ x: 500, y: 500, w: 120, h: 80 }, other, "move", o)), j({ x: 500, y: 500, w: 120, h: 80 }), "far away: untouched");
  // Resizing moves only the right and bottom edges; the corner stays.
  eq(j(w.align({ x: 100, y: 300, w: 195, h: 80 }, other, "resize", o)), j({ x: 100, y: 300, w: 200, h: 80 }), "right edge lines up when resizing");
  eq(j(w.align({ x: 100, y: 0, w: 120, h: 90 }, other, "resize", o)), j({ x: 100, y: 0, w: 120, h: 84 }), "bottom stops one gap above the neighbour");
}
// Bare widgets: the clock is its own glass, the rest keep their plate.
eq(w.bare("clock"), true, "clock is bare");
eq(w.bare("calendar"), false, "calendar has a plate");
