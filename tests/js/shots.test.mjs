import { load, eq } from "./lib.mjs";
const s = load("shots.js");
const j = JSON.stringify;

const l = s.parseList("1700000000.5\t/home/u/Pictures/Screenshots/a.png\n1700000100.25\t/home/u/b c.png\njunk\n\t/x\n12\trelative.png\n");
eq(l.length, 2, "two files, junk skipped");
eq(l[0].path, "/home/u/b c.png", "newest first");
eq(l[0].time, 1700000100250, "mtime in ms");
eq(s.parseList("1\t/a\n2\t/b\n3\t/c", 2).length, 2, "limit");
eq(s.fileUrl("/a b/#1?.png"), "file:///a%20b/%231%3F.png", "file URL");

const now = new Date(2026, 9, 25, 15, 0).getTime();
eq(s.when(new Date(2026, 9, 25, 9, 5).getTime(), now, true), "09:05", "today, 24-hour");
eq(s.when(new Date(2026, 9, 25, 14, 5).getTime(), now, false), "2:05 PM", "today, 12-hour");
eq(s.when(new Date(2026, 9, 25, 0, 30).getTime(), now, false), "12:30 AM", "after midnight, 12-hour");
eq(s.when(new Date(2026, 9, 24, 23, 0).getTime(), now, true), "Yesterday", "yesterday");
eq(s.when(new Date(2026, 9, 21, 12, 0).getTime(), now, true), "Wed", "this week");
eq(s.when(new Date(2026, 9, 3, 12, 0).getTime(), now, true), "3 Oct", "before");
eq(s.when(new Date(2025, 11, 31, 12, 0).getTime(), now, true), "31 Dec 2025", "another year");
