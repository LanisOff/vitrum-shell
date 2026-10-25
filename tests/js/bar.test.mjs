import { load, eq, ok, readJson } from "./lib.mjs";
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

// ---------------------------------------------------------- the editor API ---
const J = JSON.stringify;
const frozen = v => { Object.freeze(v); for (const k of Object.keys(v)) if (v[k] && typeof v[k] === "object") frozen(v[k]); return v; };
const base = () => frozen({ left: [["workspaces"]], center: [["context"]], activities: [["timer"]], right: [["cpu", "memory", "gpu"], ["tray", "volume"]] });

// catalog(): one entry per module, a real icon, a name and a line, options with full keys.
{
  const icons = readJson("shell/data/icons.json");
  const defaults = readJson("shell/data/settings.defaults.json");
  const sget = load("settings.js").get;
  const enums = readJson("shell/data/settings.enums.json");
  const c = b.catalog();
  eq(c.length, 28, "28 modules in the catalog");
  eq(J(c.map(e => e.id)), J(b.modules()), "catalog in MODULES order");
  for (const e of c) {
    ok(icons[e.icon], `catalog icon ${e.icon} of ${e.id} is in icons.json`);
    ok(typeof e.name === "string" && e.name.length > 0 && e.name.length <= 16, `short name for ${e.id}`);
    ok(typeof e.description === "string" && e.description.length > 10 && !e.description.includes("\n"), `one-line description for ${e.id}`);
    ok(Array.isArray(e.options), `options list for ${e.id}`);
    for (const o of e.options) {
      ok(o.type === "toggle" || o.type === "choice", `${o.key}: type`);
      ok(typeof o.label === "string" && o.label.length > 0, `${o.key}: label`);
      eq(J(sget(defaults, o.key, undefined)), J(o.def), `${o.key}: def is the shipped default`);
      if (o.type === "choice") {
        eq(o.values.length, o.names.length, `${o.key}: a name per value`);
        ok(o.values.includes(o.def), `${o.key}: def is a value`);
        eq(J(enums[o.key]), J(o.values), `${o.key}: values are the enum's`);
      }
      if (o.type === "toggle") eq(typeof o.def, "boolean", `${o.key}: toggle def is a bool`);
    }
  }
  const withOpts = c.filter(e => e.options.length).map(e => e.id).sort();
  eq(J(withOpts), J(["context", "cpu", "gpu", "keyboard", "memory", "temperature", "volume", "workspaces"]), "the modules that have options");
  eq(J(b.info("context").options.map(o => o.key)), J(["bar.modules.context.title", "clock.seconds", "clock.h24", "media.lyricsInBar"]), "context options");
  eq(J(b.info("cpu").options[0].values), J(["both", "icon", "value"]), "cpu show values");
  eq(b.info("workspaces").options[0].key, "bar.minimap", "workspaces: the minimap");
  eq(b.info("bogus"), null, "info of an unknown id");
  eq(b.info(undefined), null, "info of nothing");
  eq(b.info("cpu").name, "CPU", "info finds an entry");
  // Fresh copies: changing one does not change the next.
  const x = b.catalog(); x[0].name = "X"; x[0].options.push({}); b.info("cpu").options[0].values.push("z");
  eq(b.catalog()[0].name, "Workspaces", "catalog entries are copies");
  eq(b.catalog()[0].options.length, 1, "catalog options are copies");
  eq(b.info("cpu").options[0].values.length, 3, "info options are copies");
}

// defaultLayout(): the same as the shipped default, and a copy each time.
{
  const defaults = readJson("shell/data/settings.defaults.json");
  eq(J(b.defaultLayout()), J(defaults.bar.layout), "defaultLayout() equals settings.defaults.json bar.layout");
  const d = b.defaultLayout(); d.left.push(["cpu"]);
  eq(b.defaultLayout().left.length, 1, "defaultLayout() is a copy");
  eq(J(b.normalize(b.defaultLayout())), J(b.defaultLayout()), "the default is already normal");
}

// layoutFor(bar, screen)
{
  const shared = { left: [["workspaces"]] }, own = { right: [["cpu"]] };
  const bar = frozen({ layout: shared, screens: { "DP-1": { own: true, layout: own }, "HDMI-A-1": { own: false, layout: own }, "DP-3": { own: true } } });
  eq(b.layoutFor(bar, "DP-1"), bar.screens["DP-1"].layout, "own: the screen's layout (raw)");
  eq(b.layoutFor(bar, "HDMI-A-1"), bar.layout, "not own: the shared one");
  eq(b.layoutFor(bar, "eDP-1"), bar.layout, "a screen with no entry: the shared one");
  eq(b.layoutFor(bar, ""), bar.layout, "no screen: the shared one");
  eq(b.layoutFor(bar), bar.layout, "screen left out: the shared one");
  eq(b.layoutFor(bar, "DP-3"), bar.layout, "own without a layout: the shared one");
  eq(b.layoutFor({ layout: shared, screens: { A: { own: "yes", layout: own } } }, "A").left, shared.left, "own must be true");
  eq(J(b.layoutFor(undefined, "A")), "{}", "no bar object");
  eq(J(b.layoutFor({}, "A")), "{}", "no layout");
  eq(J(b.layoutFor({ layout: shared, screens: [] }, "0")), J(shared), "screens not a map");
}

// normalize(layout)
{
  eq(J(b.normalize(undefined)), J({ left: [], center: [], activities: [], right: [] }), "nothing → four empty sides");
  eq(J(b.normalize(null)), J({ left: [], center: [], activities: [], right: [] }), "null → four empty sides");
  eq(J(b.normalize("cpu")), J({ left: [], center: [], activities: [], right: [] }), "a string → four empty sides");
  eq(J(b.normalize({ left: "cpu", right: [["cpu", "nope"], [], "tray", 5, null, { a: 1 }, [7, "volume"]], top: [["gpu"]] })),
     J({ left: [], center: [], activities: [], right: [["cpu"], ["tray"], ["volume"]] }), "bad parts dropped, bare names islands, unknown sides ignored");
  eq(J(b.normalize({ left: [["cpu", "cpu"]], right: [["cpu"], ["memory"]] })), J({ left: [["cpu"]], center: [], activities: [], right: [["memory"]] }), "a module shows once: later copies go");
  const input = frozen({ left: [["workspaces", "x"]] });
  b.normalize(input);
  eq(input.left[0].length, 2, "normalize does not change its input");
}

// usedModules(layout)
{
  eq(J(b.usedModules(base())), J(["workspaces", "context", "timer", "cpu", "memory", "gpu", "tray", "volume"]), "ids left to right");
  eq(J(b.usedModules({ right: [["bogus", "cpu"]] })), J(["cpu"]), "only known ids");
  eq(J(b.usedModules(null)), "[]", "empty layout");
}

// moveModule: within an island.
{
  const L = base();
  eq(J(b.moveModule(L, { side: "right", island: 0, index: 0 }, { side: "right", island: 0, index: 3 }).right[0]), J(["memory", "gpu", "cpu"]), "first to the end");
  eq(J(b.moveModule(L, { side: "right", island: 0, index: 0 }, { side: "right", island: 0, index: 2 }).right[0]), J(["memory", "cpu", "gpu"]), "first before the third");
  eq(J(b.moveModule(L, { side: "right", island: 0, index: 2 }, { side: "right", island: 0, index: 0 }).right[0]), J(["gpu", "cpu", "memory"]), "last to the front");
  eq(J(b.moveModule(L, { side: "right", island: 0, index: 1 }, { side: "right", island: 0, index: 1 }).right[0]), J(["cpu", "memory", "gpu"]), "onto its own slot: no change");
  eq(J(b.moveModule(L, { side: "right", island: 0, index: 1 }, { side: "right", island: 0, index: 2 }).right[0]), J(["cpu", "memory", "gpu"]), "right after itself: no change");
  eq(J(b.moveModule(L, { side: "right", island: 0, index: 0 }, { side: "right", island: 0, index: 99 }).right[0]), J(["memory", "gpu", "cpu"]), "index past the end clamps to the end");
  eq(J(b.moveModule(L, { side: "right", island: 0, index: 2 }, { side: "right", island: 0, index: -5 }).right[0]), J(["gpu", "cpu", "memory"]), "negative index clamps to 0");
  eq(J(L.right[0]), J(["cpu", "memory", "gpu"]), "input untouched");
}

// moveModule: between islands, and between sides.
{
  const L = base();
  let r = b.moveModule(L, { side: "right", island: 0, index: 1 }, { side: "right", island: 1, index: 1 });
  eq(J(r.right), J([["cpu", "gpu"], ["tray", "memory", "volume"]]), "to another island of the side");
  r = b.moveModule(L, { side: "right", island: 1, index: 0 }, { side: "left", island: 0, index: 1 });
  eq(J(r.left), J([["workspaces", "tray"]]), "to another side: there");
  eq(J(r.right), J([["cpu", "memory", "gpu"], ["volume"]]), "to another side: gone from here");
  r = b.moveModule(L, { side: "right", island: 0, index: 0 }, { side: "center", island: 0, index: 0 });
  eq(J(r.center), J([["cpu", "context"]]), "into the centre, at the front");
  r = b.moveModule(L, { side: "right", island: 0, index: 2 }, { side: "activities", island: 5, index: 0 });
  eq(J(r.activities), J([["gpu", "timer"]]), "island past the end clamps to the last island");
  r = b.moveModule(L, { side: "left", island: 0, index: 0 }, { side: "right", island: -3, index: 99 });
  eq(J(r.right[0]), J(["cpu", "memory", "gpu", "workspaces"]), "negative island clamps to the first");
  eq(J(r.left), "[]", "the left island it left is gone");
  r = b.moveModule({ left: [["workspaces"]], right: [] }, { side: "left", island: 0, index: 0 }, { side: "right", island: 0, index: 0 });
  eq(J(r.right), J([["workspaces"]]), "into a side with no islands: a new island");
}

// moveModule: a drop into a gap makes a new island; an emptied island goes.
{
  const L = base();
  let r = b.moveModule(L, { side: "right", island: 0, index: 1 }, { side: "right", gap: 0 });
  eq(J(r.right), J([["memory"], ["cpu", "gpu"], ["tray", "volume"]]), "gap 0: a new first island");
  r = b.moveModule(L, { side: "right", island: 0, index: 1 }, { side: "right", gap: 1 });
  eq(J(r.right), J([["cpu", "gpu"], ["memory"], ["tray", "volume"]]), "gap 1: between the islands");
  r = b.moveModule(L, { side: "right", island: 0, index: 1 }, { side: "right", gap: 2 });
  eq(J(r.right), J([["cpu", "gpu"], ["tray", "volume"], ["memory"]]), "gap n: a new last island");
  r = b.moveModule(L, { side: "right", island: 0, index: 1 }, { side: "right", gap: 40 });
  eq(J(r.right), J([["cpu", "gpu"], ["tray", "volume"], ["memory"]]), "gap past the end clamps");
  r = b.moveModule(L, { side: "right", island: 0, index: 1 }, { side: "right", gap: -1 });
  eq(J(r.right[0]), J(["memory"]), "negative gap clamps to 0");
  r = b.moveModule(L, { side: "left", island: 0, index: 0 }, { side: "right", gap: 1 });
  eq(J(r.left), "[]", "the only module leaves: its island goes");
  eq(J(r.right), J([["cpu", "memory", "gpu"], ["workspaces"], ["tray", "volume"]]), "and lands in the gap");
  // Gaps and islands read against the layout as shown, before the source island goes.
  const T = frozen({ right: [["privacy"], ["cpu"], ["tray"]] });
  eq(J(b.moveModule(T, { side: "right", island: 0, index: 0 }, { side: "right", gap: 3 }).right), J([["cpu"], ["tray"], ["privacy"]]), "lone island to the last gap");
  eq(J(b.moveModule(T, { side: "right", island: 0, index: 0 }, { side: "right", gap: 2 }).right), J([["cpu"], ["privacy"], ["tray"]]), "lone island to the gap after the next");
  eq(J(b.moveModule(T, { side: "right", island: 0, index: 0 }, { side: "right", gap: 1 }).right), J(T.right), "lone island to its own gap: no change");
  eq(J(b.moveModule(T, { side: "right", island: 0, index: 0 }, { side: "right", gap: 0 }).right), J(T.right), "lone island to the gap before it: no change");
  eq(J(b.moveModule(T, { side: "right", island: 0, index: 0 }, { side: "right", island: 2, index: 0 }).right), J([["cpu"], ["privacy", "tray"]]), "into an island after the one that goes");
  eq(J(b.moveModule(T, { side: "right", island: 2, index: 0 }, { side: "right", island: 0, index: 1 }).right), J([["privacy", "tray"], ["cpu"]]), "back to an earlier island");
  eq(J(b.moveModule(T, { side: "right", island: 2, index: 0 }, { side: "center", gap: 0 })), J({ left: [], center: [["tray"]], activities: [], right: [["privacy"], ["cpu"]] }), "to an empty side's gap");
}

// moveModule: bad positions change nothing (but the result is normal).
{
  const L = base();
  for (const [from, to, what] of [
    [{ side: "top", island: 0, index: 0 }, { side: "right", gap: 0 }, "unknown from side"],
    [{ side: "right", island: 7, index: 0 }, { side: "right", gap: 0 }, "from island out of range"],
    [{ side: "right", island: 0, index: 3 }, { side: "right", gap: 0 }, "from index out of range"],
    [{ side: "right", island: 0.5, index: 0 }, { side: "right", gap: 0 }, "from island not whole"],
    [null, { side: "right", gap: 0 }, "no from"],
    [{ side: "right", island: 0, index: 0 }, { side: "top", gap: 0 }, "unknown to side"],
    [{ side: "right", island: 0, index: 0 }, null, "no to"],
  ]) eq(J(b.moveModule(L, from, to)), J(b.normalize(L)), what + ": unchanged");
  eq(J(b.moveModule({ right: [["cpu", "bogus"], []] }, { side: "right", island: 0, index: 0 }, { side: "left", gap: 0 })),
     J({ left: [["cpu"]], center: [], activities: [], right: [] }), "bad input is normalized first");
  eq(J(b.moveModule(L, { side: "right", island: "0", index: "1" }, { side: "left", island: "0", index: "0" }).left), J([["memory", "workspaces"]]), "numeric strings work");
  eq(J(b.moveModule(L, { side: "right", island: 0, index: 0 }, { side: "left", island: 0 }).left), J([["workspaces", "cpu"]]), "no index: the end of the island");
}

// insertModule: new ids go in; an id already there is moved, not doubled.
{
  const L = base();
  eq(J(b.insertModule(L, "dnd", { side: "right", island: 1, index: 1 }).right[1]), J(["tray", "dnd", "volume"]), "into an island");
  eq(J(b.insertModule(L, "dnd", { side: "left", gap: 1 }).left), J([["workspaces"], ["dnd"]]), "into a gap");
  eq(J(b.insertModule(L, "dnd", { side: "center", island: 9, index: 9 }).center), J([["context", "dnd"]]), "clamped");
  let r = b.insertModule(L, "cpu", { side: "left", island: 0, index: 0 });
  eq(J(r.left), J([["cpu", "workspaces"]]), "existing id: moved there");
  eq(J(r.right[0]), J(["memory", "gpu"]), "existing id: gone from where it was");
  eq(b.usedModules(r).filter(m => m === "cpu").length, 1, "never doubled");
  r = b.insertModule(L, "timer", { side: "right", gap: 2 });
  eq(J(r.activities), "[]", "moved out of its island: the island goes");
  eq(J(r.right[2]), J(["timer"]), "and is a new island");
  eq(J(b.insertModule(L, "gpu", { side: "right", island: 0, index: 0 }).right[0]), J(["gpu", "cpu", "memory"]), "moved within its own island");
  eq(J(b.insertModule(L, "bogus", { side: "left", gap: 0 })), J(b.normalize(L)), "unknown id: unchanged");
  eq(J(b.insertModule(L, "dnd", { side: "nowhere", gap: 0 })), J(b.normalize(L)), "unknown side: unchanged");
  eq(J(b.insertModule(null, "dnd", { side: "right", island: 0, index: 0 }).right), J([["dnd"]]), "into an empty layout");
  eq(J(L.right[1]), J(["tray", "volume"]), "input untouched");
}

// removeModule
{
  const L = base();
  eq(J(b.removeModule(L, { side: "right", island: 0, index: 1 }).right[0]), J(["cpu", "gpu"]), "removed");
  eq(J(b.removeModule(L, { side: "left", island: 0, index: 0 }).left), "[]", "the last one: its island goes");
  eq(J(b.removeModule(L, { side: "right", island: 4, index: 0 })), J(b.normalize(L)), "out of range: unchanged");
  eq(J(b.removeModule(L, null)), J(b.normalize(L)), "nothing: unchanged");
  eq(J(b.removeModule({ left: ["workspaces", "nope"] }, { side: "left", island: 0, index: 0 })), J({ left: [], center: [], activities: [], right: [] }), "bad input normalized");
  eq(J(L.left), J([["workspaces"]]), "input untouched");
}

// withMinimap(layout, on): the workspaces' option puts a minimap right after them.
{
  const L = base();
  eq(J(b.withMinimap(L, false)), J(b.normalize(L)), "off: as is");
  eq(J(b.withMinimap(L, true).left), J([["workspaces", "minimap"]]), "on: right after the workspaces");
  eq(J(b.withMinimap({ left: [["workspaces"]], right: [["minimap"]] }, true)), J({ left: [["workspaces"]], center: [], activities: [], right: [["minimap"]] }), "a placed minimap is not doubled");
  eq(J(b.withMinimap({ right: [["cpu"]] }, true).right), J([["cpu"]]), "no workspaces: nothing to add to");
  eq(J(L.left), J([["workspaces"]]), "input untouched");
}

// planList / planIslands: what the bar does to its ListModels; replaying the
// ops gives the new list, and what stays keeps its row.
function replay(rows, ops) {
  rows = rows.map(r => Object.assign({}, r));
  for (const o of ops) {
    if (o.op === "remove") rows.splice(o.index, 1);
    else if (o.op === "move") { const [x] = rows.splice(o.from, 1); rows.splice(o.to, 0, x); }
    else if (o.op === "insert") rows.splice(o.index, 0, "uid" in o ? { uid: o.uid, mods: o.mods } : { key: o.key });
    else if (o.op === "set") rows[o.index].mods = o.mods;
  }
  return rows;
}
{
  for (const [a, z] of [[["a", "b", "c"], ["c", "a", "b"]], [["a", "b", "c"], ["b"]], [[], ["x", "y"]], [["a", "b"], []], [["a", "b", "c", "d"], ["d", "x", "b", "a"]], [["a"], ["a"]]]) {
    const ops = b.planList(a, z);
    eq(J(replay(a.map(key => ({ key })), ops).map(r => r.key)), J(z), `planList ${a} → ${z}`);
  }
  eq(b.planList(["a", "b"], ["a", "b"]).length, 0, "planList: nothing to do");
  eq(J(b.planList(["a", "b", "c"], ["a", "c"])), J([{ op: "remove", index: 1 }]), "planList: just the removal");

  const old = [["cpu", "memory", "gpu"], ["tray", "volume"]];
  let p = b.planIslands(old, [3, 4], [["cpu", "gpu"], ["memory"], ["tray", "volume"]], 5);
  eq(J(p.uids), J([3, 5, 4]), "islands keep their uid; the new one gets the next");
  eq(p.next, 6, "next uid");
  let rows = replay([{ uid: 3, mods: "cpu,memory,gpu" }, { uid: 4, mods: "tray,volume" }], p.ops);
  eq(J(rows), J([{ uid: 3, mods: "cpu,gpu" }, { uid: 5, mods: "memory" }, { uid: 4, mods: "tray,volume" }]), "replayed islands");
  p = b.planIslands(old, [3, 4], [["tray", "volume"]], 5);
  eq(J(replay([{ uid: 3, mods: "cpu,memory,gpu" }, { uid: 4, mods: "tray,volume" }], p.ops)), J([{ uid: 4, mods: "tray,volume" }]), "a removed island goes, the other stays");
  p = b.planIslands(old, [3, 4], [["tray", "volume"], ["cpu", "memory", "gpu"]], 5);
  eq(J(p.uids), J([4, 3]), "swapped islands keep their uids");
  eq(p.ops.some(o => o.op === "insert" || o.op === "remove"), false, "a swap only moves");
  p = b.planIslands([], [], [["workspaces"]], 0);
  eq(J(replay([], p.ops)), J([{ uid: 0, mods: "workspaces" }]), "from nothing");
  p = b.planIslands(old, [3, 4], old.map(i => i.slice()), 5);
  eq(p.ops.length, 0, "the same islands: nothing to do");
}
