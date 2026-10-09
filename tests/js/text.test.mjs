import { load, eq } from "./lib.mjs";
const t = load("text.js");
eq(t.elide("abcdefgh", 5), "abcd…", "elide");
eq(t.elide("abc", 5), "abc", "short unchanged");
eq(t.formatBytes(1536), "1.5 KiB", "bytes");
eq(t.formatPercent(0.427), "43%", "percent");
eq(JSON.stringify(t.clockParts(new Date(2026, 9, 1, 9, 5, 7), true)), JSON.stringify({ hh: "09", mm: "05", ss: "07", ampm: "" }), "24h");
eq(t.clockParts(new Date(2026, 9, 1, 21, 5, 7), false).ampm, "PM", "12h");
