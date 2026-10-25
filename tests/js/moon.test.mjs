import { load, eq, ok } from "./lib.mjs";
const m = load("moon.js");
const near = (a, b, tol) => Math.abs(a - b) <= tol;
const min = 60000;

// Meeus, example 49.a: the new moon of February 1977 (k = −283), JDE 2443192.65118.
ok(near(m.phaseJDE(-283), 2443192.65118, 0.0002), `new moon 1977: ${m.phaseJDE(-283)}`);
// k = 0 is the new moon of 6 January 2000, 18:14 UT.
ok(near(m.phaseDate(0).getTime(), Date.UTC(2000, 0, 6, 18, 14), 3 * min), "new moon 2000-01-06 18:14");

// Phases of 2026 (UT), as published: the next of each kind after a date.
const utc = (y, mo, d, h, mi) => new Date(Date.UTC(y, mo - 1, d, h, mi));
const close = (got, want, what) => ok(near(got.getTime(), want.getTime(), 10 * min), `${what}: ${got.toISOString()}`);
close(m.nextFull(utc(2025, 12, 25, 0, 0)), utc(2026, 1, 3, 10, 3), "full moon 3 Jan 2026");
close(m.nextFull(utc(2026, 2, 20, 0, 0)), utc(2026, 3, 3, 11, 38), "full moon 3 Mar 2026 (the eclipse)");
close(m.nextNew(utc(2026, 8, 1, 0, 0)), utc(2026, 8, 12, 17, 37), "new moon 12 Aug 2026 (the eclipse)");
close(m.nextNew(utc(2026, 2, 10, 0, 0)), utc(2026, 2, 17, 12, 1), "new moon 17 Feb 2026 (annular)");
// Strictly after: from the very moment of one, the next is a month on.
{
  const f = m.nextFull(utc(2026, 2, 20, 0, 0));
  const g = m.nextFull(new Date(f.getTime() + 1000));
  ok(near(g.getTime() - f.getTime(), 29.53 * 86400000, 1.2 * 86400000), "the next full moon after one is a month on");
  ok(m.nextNew(utc(2026, 8, 12, 17, 0)).getTime() > utc(2026, 8, 12, 17, 0).getTime(), "next is in the future");
}

// The lit fraction: Meeus example 48.a (1992 April 12, 0h TD), 0.6786; the
// low-precision angle gives 0.680.
ok(near(m.illumination(m.fromJD(2448724.5 - 69 / 86400)), 0.6786, 0.004), "illumination 1992-04-12");
// At a full moon nearly all lit, at a new moon nearly none.
ok(m.illumination(utc(2026, 3, 3, 11, 38)) > 0.99, "full: lit");
ok(m.illumination(utc(2026, 8, 12, 17, 37)) < 0.01, "new: dark");

// Names: a principal phase all of its local day; between them by the side.
{
  const full = m.nextFull(utc(2026, 2, 20, 0, 0));
  const local = new Date(full.getFullYear(), full.getMonth(), full.getDate(), 0, 30);
  eq(m.info(local).name, "Full moon", "full moon all of its day, even at half past midnight");
  eq(m.info(local).phase, "full", "its key");
  const before = new Date(full.getTime() - 3 * 86400000);
  eq(m.info(before).name, "Waxing gibbous", "three days before full");
  eq(m.info(before).waxing, true, "waxing then");
  const after = new Date(full.getTime() + 4 * 86400000);
  eq(m.info(after).name, "Waning gibbous", "four days after");
  const nw = m.nextNew(utc(2026, 8, 1, 0, 0));
  eq(m.info(new Date(nw.getTime() + 4 * 86400000)).name, "Waxing crescent", "four days after new");
  eq(m.info(new Date(nw.getTime() - 4 * 86400000)).name, "Waning crescent", "four days before new");
  const fq = m.next(nw, 0.25);
  ok(fq.getTime() > nw.getTime() && fq.getTime() - nw.getTime() < 9 * 86400000, "the first quarter follows the new moon within a week or so");
  eq(m.info(fq).name, "First quarter", "first quarter at its moment");
  ok(near(m.info(fq).illumination, 0.5, 0.03), "half lit at the quarter");
  const lq = m.next(nw, 0.75);
  eq(m.info(lq).name, "Last quarter", "last quarter at its moment");
}

// The drawing: lit on the right while waxing, a crescent bulging toward the
// limb, a gibbous moon away from it; the south mirrors it.
eq(JSON.stringify(m.shape(45, false).side), "1", "waxing: right");
ok(m.shape(45, false).bulge > 0, "crescent bulges to the limb");
ok(m.shape(135, false).bulge < 0, "gibbous away from it");
eq(m.shape(225, false).side, -1, "waning: left");
eq(m.shape(45, true).side, -1, "south: mirrored");
ok(near(m.shape(90, false).bulge, 0, 1e-9), "quarter: a straight terminator");
