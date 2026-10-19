import { load, eq, ok, readJson } from "./lib.mjs";
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
// On every screen: the same widget on each, and in the way of new ones everywhere.
{
  const every = items.concat([{ id: "c", type: "clock", output: w.EVERY, x: 32, y: 80, w: 336, h: 160 }]);
  eq(j(w.forOutput(every, "DP-1").map(i => i.id)), j(["a", "c"]), "every screen shows on DP-1");
  eq(j(w.forOutput(every, "eDP-1").map(i => i.id)), j(["c"]), "and on any other");
  eq(j(w.forOutput(every, w.EVERY).map(i => i.id)), j(["a", "b", "c"]), "every screen keeps clear of all");
  const next = w.add(every, "clock", "HDMI-A-1", screen, 8, 48, () => "d");
  eq(next[3].x !== 32 || next[3].y !== 80, true, "a new widget does not land on it");
  eq(w.moveToOutput(every, "c", "DP-1", { x: 32, y: 80 }, screen, 8)[2].output, "DP-1", "back to one screen");
}

// Updating returns a new list; the others are untouched.
const up = w.update(items, "a", { x: 40 });
eq(up[0].x, 40, "patched");
eq(items[0].x, undefined, "original unchanged");
eq(up[1], items[1], "others are the same objects");
eq(j(w.remove(items, "a").map(i => i.id)), j(["b"]), "remove");

// Adding: the type's default size, at the first free grid spot from the top left
// (below the bar margin), on that output; ids are unique.
const added = w.add([], "clock", "DP-1", screen, 8, 48, () => "id1");
eq(j(added[0]), j({ id: "id1", type: "clock", output: "DP-1", x: 32, y: 80, w: 336, h: 160, options: {} }), "first clock");
const two = w.add(added, "clock", "DP-1", screen, 8, 48, () => "id2");
eq(two[1].y > two[0].y + two[0].h - 1 || two[1].x >= two[0].x + two[0].w, true, "second does not overlap the first");
const other = w.add(added, "clock", "HDMI-A-1", screen, 8, 48, () => "id3");
eq(j({ x: other[1].x, y: other[1].y }), j({ x: 32, y: 80 }), "another output's widgets do not block");

// Interactive types take input outside edit mode; the rest let clicks through.
eq(w.interactive("notes"), true, "notes");
eq(w.interactive("media"), true, "media");
eq(w.interactive("shortcuts"), true, "shortcuts");
eq(w.interactive("clock"), false, "clock");

// Unknown types stay (a "Missing widget" plate that can be removed — an older
// or newer build's widget must not vanish on the next save); bad numbers fixed.
eq(j(w.sanitize([{ id: "x", type: "bogus", output: "DP-1", x: 1, y: 2, w: 160, h: 160 }, { type: "clock", output: "DP-1", x: "a" }], () => "n1")),
   j([{ id: "x", type: "bogus", output: "DP-1", x: 1, y: 2, w: 160, h: 160, options: {} },
      { id: "n1", type: "clock", output: "DP-1", x: 0, y: 0, w: 336, h: 160, options: {} }]), "sanitize");
eq(w.sanitize([{ id: "e", type: "", output: "DP-1" }, { id: "n", type: 5, output: "DP-1" }], () => "n").length, 0, "no type at all: dropped");

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

// ---------------------------------------------------------------- editor ---
// The catalog: every widget complete, its icon real, its sizes and schema valid.
{
  const icons = readJson("shell/data/icons.json");
  for (const t of w.types()) {
    const m = w.CATALOG[t];
    ok(m.name && m.icon && m.category, `${t}: name, icon, category`);
    ok(!!icons[m.icon], `${t}: icon ${m.icon} exists`);
    ok(m.sizes.length > 0 && m.sizes.every(s => ["S", "M", "L", "XL"].includes(s)), `${t}: sizes`);
    ok(m.sizes.includes(m.def), `${t}: default size is allowed`);
    for (const o of m.options) {
      ok(o.key && o.label && ["bool", "choice", "text", "number", "list", "color", "folder"].includes(o.type), `${t}.${o.key}: schema`);
      if (o.type === "choice") ok(Array.isArray(o.choices) && o.choices.some(c => c.value === o.default), `${t}.${o.key}: default among choices`);
    }
  }
  eq(w.types().length, 26, "26 built-in types");
}
// Size presets: cells of 72 with 16 between.
eq(j(w.presetSize("S")), j({ w: 160, h: 160 }), "S");
eq(j(w.presetSize("M")), j({ w: 336, h: 160 }), "M");
eq(j(w.presetSize("L")), j({ w: 336, h: 336 }), "L");
eq(j(w.presetSize("XL")), j({ w: 512, h: 336 }), "XL");
// Any free size reads as the nearest class.
eq(w.sizeClass(160, 160), "S", "small");
eq(w.sizeClass(336, 160), "M", "wide");
eq(w.sizeClass(336, 336), "L", "large");
eq(w.sizeClass(512, 336), "XL", "extra large");
eq(w.sizeClass(200, 400), "L", "tall and narrow reads as large");
// Unknown types: a placeholder, so an old config still opens.
eq(w.meta("nope").missing, true, "unknown type → placeholder");
eq(w.meta("script:x", { "script:x": { name: "Mine", icon: "code" } }).name, "Mine", "custom meta");
// Options: missing keys and wrong types fall back to the schema's defaults.
{
  const wd = w.withDefaults("clock", { seconds: "yes", style: "bogus" });
  eq(typeof wd.seconds, "boolean", "wrong type → default");
  ok(w.CATALOG.clock.options.find(o => o.key === "style").choices.some(c => c.value === wd.style), "bad choice → default");
  const keys = w.CATALOG.clock.options.map(o => o.key);
  ok(keys.every(k => k in wd), "every key present");
  eq(j(w.withDefaults("notes", { text: "hi" }).text), j("hi"), "content kept");
  eq(j(w.withDefaults("worldclock", { zones: "x" }).zones), j(w.CATALOG.worldclock.options.find(o => o.key === "zones").default), "list must be a list");
}
// The stage: right of the sheet with it, centred without; mapping round trips.
{
  const st = w.stageRect({ w: 1920, h: 1080 }, 380, 0.72, true, 24);
  eq(st.scale, 0.72, "scale kept");
  ok(st.x >= 380 + 24, "stage right of the sheet");
  ok(st.x + st.w <= 1920 - 24 + 0.5, "stage on screen");
  const p = w.fromStage(w.toStage({ x: 100, y: 50 }, st), st);
  eq(Math.round(p.x) + "," + Math.round(p.y), "100,50", "toStage/fromStage round trip");
  const c = w.stageRect({ w: 1920, h: 1080 }, 380, 0.72, false, 24);
  eq(Math.round(c.x + c.w / 2), 960, "no sheet → centred");
  const tight = w.stageRect({ w: 1280, h: 720 }, 380, 0.72, true, 24);
  ok(tight.x + tight.w <= 1280 - 24 + 0.5, "a narrow screen shrinks the stage to fit");
}
// Duplicate: beside the original when it fits, with its options.
{
  const base = [{ id: "a", type: "clock", output: "DP-1", x: 32, y: 80, w: 320, h: 160, options: { seconds: true } }];
  const dup = w.duplicate(base, "a", () => "b", screen, 8);
  eq(dup.length, 2, "one more");
  eq(dup[1].x, 32 + 320 + 16, "beside the original");
  eq(dup[1].y, 80, "same row");
  eq(j(dup[1].options), j({ seconds: true }), "options copied");
  ok(dup[1].options !== base[0].options, "options are a copy");
  const edge = [{ id: "a", type: "clock", output: "DP-1", x: 1600, y: 80, w: 320, h: 160, options: {} }];
  const d2 = w.duplicate(edge, "a", () => "b", screen, 8);
  eq(d2[1].y, 80 + 160 + 16, "no room to the right → below");
}
// Align and distribute a selection.
{
  const three = [
    { id: "a", x: 10, y: 0, w: 100, h: 50 }, { id: "b", x: 200, y: 40, w: 100, h: 50 }, { id: "c", x: 600, y: 100, w: 100, h: 50 }];
  eq(w.alignItems(three, ["a", "b"], "top").find(i => i.id === "b").y, 0, "align top");
  eq(w.alignItems(three, ["a", "b"], "right").find(i => i.id === "a").x, 200, "align right");
  eq(w.alignItems(three, ["a", "b"], "hcenter").find(i => i.id === "a").x, 105, "align centres");
  eq(w.alignItems(three, ["a", "b"], "bottom").find(i => i.id === "c").y, 100, "unselected untouched");
  const dist = w.distribute(three, ["a", "b", "c"], "h");
  eq(dist.find(i => i.id === "b").x, 305, "equal gaps");
  eq(w.distribute(three, ["a", "b"], "h"), three, "fewer than three → unchanged");
}
// Another screen: the output changes, the widget stays on it.
{
  const base = [{ id: "a", type: "clock", output: "DP-1", x: 32, y: 80, w: 320, h: 160, options: {} }];
  const moved = w.moveToOutput(base, "a", "HDMI-A-1", { x: 5000, y: 20 }, screen, 8);
  eq(moved[0].output, "HDMI-A-1", "moved output");
  eq(moved[0].x, 1920 - 320, "kept on the new screen");
}
// History: undo gives back the previous draft, redo the undone one; a new edit clears redo.
{
  let h = { undo: [], redo: [] };
  h = w.historyPush(h, "A").h; h = w.historyPush(h, "B").h;
  let r = w.historyUndo(h, "C"); eq(r.value, "B", "undo gives the last snapshot"); h = r.h;
  r = w.historyRedo(h, "B"); eq(r.value, "C", "redo gives back the current"); h = r.h;
  eq(w.historyUndo({ undo: [], redo: [] }, "X").value, null, "nothing to undo");
  eq(w.historyRedo({ undo: [], redo: [] }, "X").value, null, "nothing to redo");
  h = w.historyPush(w.historyUndo(h, "C").h, "D").h; eq(h.redo.length, 0, "push clears redo");
  let big = { undo: [], redo: [] };
  for (let i = 0; i < 120; i++) big = w.historyPush(big, i).h;
  eq(big.undo.length, 100, "history capped at 100");
}
// What a script prints.
eq(j(w.parseScriptOutput("42%\nDisk used\nrest").items), j(["rest"]), "plain: further lines are items");
eq(w.parseScriptOutput("42%\nDisk used").value, "42%", "plain value");
eq(w.parseScriptOutput("42%\nDisk used").subtitle, "Disk used", "plain subtitle");
eq(w.parseScriptOutput('{"value":3,"unit":"GB","progress":1.7}').progress, 1, "progress clamped");
eq(w.parseScriptOutput('{"value":3,"unit":"GB"}').value, "3", "numbers become text");
eq(w.parseScriptOutput('{"items":' + JSON.stringify(Array(80).fill("x")) + '}').items.length, 50, "items capped");
eq(w.parseScriptOutput("").value, "", "empty");
eq(w.parseScriptOutput("y".repeat(500)).value.length, 200, "long line cut");
eq(w.parseScriptOutput("{broken").value, "{broken", "bad JSON reads as text");
eq(j(w.parseScriptOutput('{"history":[1,"a",3]}').history), j([1, 3]), "history keeps numbers");
// Custom types survive loading; unknown built-ins do not.
eq(w.sanitize([{ id: "s", type: "script:abc", output: "DP-1" }, { id: "q", type: "qml:my", output: "DP-1" }, { id: "z", type: "zzz", output: "DP-1" }], () => "n").length, 3, "custom and unknown kept");
// A QML widget's manifest with a broken schema does not take the desktop down.
{
  const custom = { "qml:x": { name: "X", options: [{ key: "a", label: "A", type: "choice", default: "1", choices: "nope" }] } };
  eq(w.withDefaults("qml:x", { a: "2" }, custom).a, "2", "choices that are not a list: the value is kept");
}
// A preset keeps the corner and stays on screen.
{
  const it = { id: "a", type: "weather", output: "DP-1", x: 1700, y: 80, w: 160, h: 160, options: {} };
  eq(j(w.presetRect(it, "L", screen, 8)), j({ x: 1584, y: 80, w: 336, h: 336 }), "grown, pushed back on screen");
}
// Dropped past the window's edge: the output under the global point, and the
// place on its (sheet-less, centred) stage.
{
  const outs = { "DP-1": { x: 0, y: 0, width: 1920, height: 1080 }, "HDMI-A-1": { x: 1920, y: 0, width: 1920, height: 1080 } };
  eq(w.outputAt(outs, 2000, 500), "HDMI-A-1", "point on the right screen");
  eq(w.outputAt(outs, 100, 100), "DP-1", "point on the left screen");
  eq(w.outputAt(outs, -5, 100), "", "nowhere");
  // From DP-1's window, a point 600 px past its right edge → HDMI-A-1's stage centre area.
  const d = w.dropTarget(outs, "DP-1", { x: 1920 + 960, y: 540 }, 380, 0.72, 24);
  eq(d.output, "HDMI-A-1", "drop goes to the other screen");
  eq(Math.round(d.x) + "," + Math.round(d.y), "960,540", "the stage centre maps to the screen centre");
  eq(w.dropTarget(outs, "DP-1", { x: 500, y: 500 }, 380, 0.72, 24), null, "inside its own window: no move");
}
// Which file shows a type: built-ins by name, custom ones by kind.
eq(w.widgetFile("clock"), "ClockWidget.qml", "built-in file");
eq(w.widgetFile("worldclock"), "WorldClockWidget.qml", "camel-cased file");
eq(w.widgetFile("script:abc"), "ScriptWidget.qml", "script widgets");
eq(w.widgetFile("qml:mine"), "QmlWidget.qml", "QML widgets");
eq(w.widgetFile("nope"), "", "unknown: none");
for (const t of w.types()) ok(w.widgetFile(t).endsWith("Widget.qml"), `${t} has a file`);
