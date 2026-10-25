import { load, eq } from "./lib.mjs";
const s = load("stopwatch.js");
const j = JSON.stringify;

// Time comes from the timestamps, not from ticks.
let st = s.reset();
eq(s.elapsed(st, 5000), 0, "stopped at zero");
eq(s.running(st), false, "not running");
st = s.start(st, 1000);
eq(s.running(st), true, "running");
eq(s.elapsed(st, 61000), 60000, "a minute on");
eq(s.start(st, 9000).since, 1000, "start while running: unchanged");
st = s.pause(st, 31000);
eq(j(st), j({ since: 0, acc: 30000, laps: [] }), "paused keeps 30 s");
eq(s.elapsed(st, 999999), 30000, "and stays there");
st = s.start(st, 100000);
eq(s.elapsed(st, 110000), 40000, "resumed: adds on");
eq(s.elapsed({ since: 2000, acc: 0 }, 1000), 0, "a clock set back: never negative");
eq(s.elapsed({}, 1000), 0, "empty options: zero");

// Laps: totals stored, splits shown newest first; best and worst from three on.
{
  let l = s.lap(s.start(s.reset(), 1000), 11000);
  l = s.lap(l, 26000);
  eq(j(l.laps), j(["10000", "25000"]), "totals as strings");
  eq(s.running(l), true, "a lap does not stop it");
  eq(j(s.laps(l).map(x => [x.n, x.split, x.best, x.worst])), j([[2, 15000, false, false], [1, 10000, false, false]]), "two: no best or worst");
  l = s.lap(l, 34000);
  eq(j(s.laps(l).map(x => [x.n, x.split, x.best, x.worst])), j([[3, 8000, true, false], [2, 15000, false, true], [1, 10000, false, false]]), "three: best and worst");
  eq(s.laps({ laps: ["x", "-5", "700"] }).length, 1, "bad entries left out");
}

// Format: tenths under an hour, h:mm:ss above.
eq(s.format(0), "0:00.0", "zero");
eq(s.format(7450), "0:07.4", "tenths, truncated");
eq(s.format(754000 + 500), "12:34.5", "minutes");
eq(s.format(3723000), "1:02:03", "hours, no tenths");
eq(s.format(65000, false), "1:05", "without tenths");
