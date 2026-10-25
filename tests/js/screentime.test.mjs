import { load, eq } from "./lib.mjs";
const s = load("screentime.js");
const j = JSON.stringify;
const at = (d, h, m) => new Date(2026, 9, d, h, m || 0).getTime();

eq(s.dayKey(at(5, 9)), "2026-10-05", "day key, padded");
let days = s.credit({}, "firefox", at(25, 10), at(25, 10, 30));
eq(days["2026-10-25"].firefox, 1800, "half an hour");
days = s.credit(days, "firefox", at(25, 11), at(25, 11, 1));
eq(days["2026-10-25"].firefox, 1860, "added up");
const before = days;
days = s.credit(days, "kitty", at(25, 23, 50), at(26, 0, 20));
eq(days["2026-10-25"].kitty, 600, "split at midnight: before");
eq(days["2026-10-26"].kitty, 1200, "split at midnight: after");
eq(before["2026-10-25"].kitty, undefined, "the old object is left alone");
eq(j(s.credit(days, "", at(25, 1), at(25, 2))), j(days), "no app: nothing");
eq(j(s.credit(days, "x", at(25, 2), at(25, 1))), j(days), "no time: nothing");

eq(j(Object.keys(s.prune({ "2026-10-18": {}, "2026-10-19": {}, "2026-10-25": {} }, at(25, 12), 7))), j(["2026-10-19", "2026-10-25"]), "a week kept");
eq(j(Object.keys(s.prune({ "2026-09-30": {}, "2026-10-01": {} }, at(1, 8), 1))), j(["2026-10-01"]), "across a month");

eq(j(s.sanitize({ days: { "2026-10-25": { a: 5, b: "x", c: -1, d: NaN }, nope: { a: 1 }, "2026-10-24": 3 } })),
   j({ "2026-10-25": { a: 5 } }), "sanitize");
eq(j(s.sanitize(null)), "{}", "sanitize nothing");
eq(j(s.sanitize({ days: [] })), "{}", "an empty list is no days");

const day = { kitty: 600, firefox: 3600, code: 3600, blip: 0.4 };
eq(s.total(day), 7800.4, "total");
eq(j(s.ranked(day).map(r => r.app)), j(["code", "firefox", "kitty"]), "most used first, ties by name, under a second left out");
eq(s.ranked(day, 1).length, 1, "the first n");

eq(s.duration(30), "< 1 min", "under a minute");
eq(s.duration(35 * 60), "35 min", "minutes");
eq(s.duration(2 * 3600 + 5 * 60), "2 h 05 min", "hours and minutes");
eq(s.duration(3600), "1 h", "whole hours");
eq(s.duration(2 * 3600 + 5 * 60, true), "2h 05m", "compact");
eq(s.duration(59, true), "<1m", "compact, under a minute");
