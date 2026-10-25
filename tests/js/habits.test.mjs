import { load, eq } from "./lib.mjs";
const h = load("habits.js");
const j = JSON.stringify;
const today = new Date(2026, 9, 25, 15, 0);

eq(h.dayKey(new Date(2026, 0, 5)), "2026-01-05", "day key");
eq(h.dayKey(h.addDays(new Date(2026, 2, 1), -1)), "2026-02-28", "back over a month");

// Marks follow the names; a new habit starts empty.
{
  const r = h.resolve(["Read", "Walk", "Water"], ["Read\t2026-10-24 2026-10-25", "Walk\t2026-10-20"]);
  eq(j(r.map(x => Object.keys(x.days).length)), j([2, 1, 0]), "by name");
}
// Removing one keeps the others' days; so does removing and adding at once.
{
  const marks = ["Read\t2026-10-24", "Walk\t2026-10-23", "Water\t2026-10-22"];
  eq(j(h.resolve(["Read", "Water"], marks).map(x => Object.keys(x.days))), j([["2026-10-24"], ["2026-10-22"]]), "removed one");
  eq(j(h.resolve(["Read", "Water", "Stretch"], marks).map(x => Object.keys(x.days))), j([["2026-10-24"], ["2026-10-22"], []]), "removed one, added one: the new one is fresh");
  // Renamed in place: the new name at the old one's position, which is gone.
  eq(j(h.resolve(["Read", "Run", "Water"], marks).map(x => Object.keys(x.days))), j([["2026-10-24"], ["2026-10-23"], ["2026-10-22"]]), "renamed keeps its days");
}
// Toggling: on, off; the marks saved in the habits' order with the new names.
{
  let m = h.toggle(["Read", "Run"], ["Read\t", "Walk\t2026-10-23"], 1, "2026-10-25", today);
  eq(j(m), j(["Read\t", "Run\t2026-10-23 2026-10-25"]), "on, renamed carried over, sorted");
  m = h.toggle(["Read", "Run"], m, 1, "2026-10-23", today);
  eq(j(m), j(["Read\t", "Run\t2026-10-25"]), "off");
  eq(j(h.toggle(["A"], ["A\t2020-01-01 2026-10-01"], 0, "2026-10-25", today)), j(["A\t2026-10-01 2026-10-25"]), "very old days dropped");
  eq(j(h.toggle(["A"], [], 5, "2026-10-25", today)), j(["A\t"]), "a bad index changes nothing");
}
// The week row and the streak.
{
  const days = { "2026-10-25": true, "2026-10-24": true, "2026-10-23": true, "2026-10-21": true };
  const w = h.week(days, today, 7);
  eq(w.length, 7, "seven days");
  eq(w[6].key, "2026-10-25", "today last");
  eq(j(w.map(x => x.done)), j([false, false, true, false, true, true, true]), "done days");
  eq(h.streak(days, today), 3, "three in a row");
  const notYet = { "2026-10-24": true, "2026-10-23": true };
  eq(h.streak(notYet, today), 2, "today not done yet: the streak holds");
  eq(h.streak({ "2026-10-23": true }, today), 0, "a gap breaks it");
  eq(h.streak({}, today), 0, "none");
}
// Blank names are no habits; a mark with no days is fine.
eq(h.resolve(["", "  ", "Read"], ["Read"]).length, 1, "blank names left out");
