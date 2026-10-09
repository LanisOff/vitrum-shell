import { load, eq, ok } from "./lib.mjs";
const d = load("drop.js");
const island = { x: 600, y: 10, w: 220, h: 34 };
const target = { x: 520, w: 380, h: 300 };

// Closed: the sheet is a sliver of the island's width, right under it, no neck yet.
{
  const g = d.dropGeometry(island, target, 0, 10);
  eq(g.neck.h, 0, "no neck when closed");
  eq(g.sheet.h, 0, "no sheet when closed");
  eq(g.sheet.w, island.w, "starts as wide as the island");
  eq(g.sheet.x, island.x, "starts under the island");
  eq(g.sheet.y, island.y + island.h, "starts at the island's bottom");
}
// Open: the panel's own rect, hanging from a neck as long as the gap.
{
  const g = d.dropGeometry(island, target, 1, 10);
  eq(g.neck.y, island.y + island.h, "neck from the island's bottom");
  eq(g.neck.h, 10, "neck as long as the gap");
  eq(g.neck.x, island.x, "neck as wide as the island");
  eq(g.neck.w, island.w, "neck as wide as the island");
  eq(JSON.stringify(g.sheet), JSON.stringify({ x: 520, y: 54, w: 380, h: 300 }), "sheet at its target");
}
// Overshoot stretches the height, never the width past the target.
{
  const g = d.dropGeometry(island, target, 1.08, 10);
  ok(g.sheet.h > 300, "overshoot stretches the height");
  eq(g.sheet.w, 380, "width stays at the target");
}
// Halfway: between the island and the target, centred between their centres.
{
  const g = d.dropGeometry(island, target, 0.5, 10);
  ok(g.sheet.w > island.w && g.sheet.w < target.w, "width in between");
  ok(g.sheet.h > 0 && g.sheet.h < target.h, "height in between");
}

// Outline: the island, its neck and the sheet as one path with concave fillets.
{
  const g = d.dropGeometry(island, target, 1, 10);
  const p = d.dropPath(island, g.sheet, 17, 16, false, 1000);
  ok(p.startsWith("M"), "a path");
  ok(p.endsWith("Z"), "closed");
  eq((p.match(/A [\d.]+ [\d.]+ 0 0 0 /g) || []).length, 2, "two concave fillets");
  eq((p.match(/A [\d.]+ [\d.]+ 0 0 1 /g) || []).length, 6, "six convex corners");
}
// A sheet flush with the island on one side: a straight edge there, one fillet.
{
  const isl = { x: 1500, y: 10, w: 150, h: 34 };
  const sheet = { x: 1290, y: 54, w: 360, h: 200 };
  const p = d.dropPath(isl, sheet, 17, 16, false, 1000);
  eq((p.match(/A [\d.]+ [\d.]+ 0 0 0 /g) || []).length, 1, "one fillet");
}
// A bottom bar: the same outline mirrored — sweep flags flip.
{
  const g = d.dropGeometry(island, target, 1, 10);
  const p = d.dropPath(island, g.sheet, 17, 16, true, 1000);
  eq((p.match(/A [\d.]+ [\d.]+ 0 0 1 /g) || []).length, 2, "fillets flip when mirrored");
  ok(!/NaN/.test(p), "no NaN");
}
// Nothing open: no path.
eq(d.dropPath(island, { x: 0, y: 0, w: 0, h: 0 }, 17, 16, false, 1000), "", "no sheet, no path");
// mirrorRect: a top-frame rect on a bottom bar.
eq(JSON.stringify(d.mirrorRect({ x: 1, y: 10, w: 5, h: 20 }, true, 100)), JSON.stringify({ x: 1, y: 70, w: 5, h: 20 }), "mirrored rect");
eq(JSON.stringify(d.mirrorRect({ x: 1, y: 10, w: 5, h: 20 }, false, 100)), JSON.stringify({ x: 1, y: 10, w: 5, h: 20 }), "top bar unchanged");
// A sheet narrower than the island: the neck narrows onto its flat top, never
// past its rounded corners; and narrows gradually, not in a jump.
{
  const wide = { x: 500, y: 10, w: 600, h: 34 };
  const narrow = { x: 650, w: 300, h: 300 };
  const g = d.dropGeometry(wide, narrow, 1, 10, 17);
  eq(g.neck.x, 650 + 17, "neck starts inside the sheet's left corner");
  eq(g.neck.w, 300 - 34, "neck ends inside the sheet's right corner");
  const same = d.dropGeometry(wide, { x: 500, w: 600, h: 300 }, 1, 10, 17);
  eq(same.neck.w, 600, "as wide as the island when the sheet is too");
  const close = d.dropGeometry(wide, { x: 502, w: 596, h: 300 }, 1, 10, 17);
  ok(close.neck.w > 596 - 34 && close.neck.w <= 596, "a little narrower: a little inset");
  const p = d.dropPath(wide, g.sheet, 17, 16, false, 1000, g.neck);
  ok(p.includes("M 667 "), "outline carries the narrowed neck");
  ok(!/NaN/.test(p), "no NaN");
  const old = d.dropGeometry(wide, narrow, 1, 10);
  eq(old.neck.w, 600, "no radius: neck as before");
}
