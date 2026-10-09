import { load, eq } from "./lib.mjs";
const l = load("lyrics.js");

const lrc = "[ar: Someone]\n[00:01.50] First line\n[00:04.00]Second line\n[00:04.00]\n[01:02.25] Third [with brackets]\n[00:00.00] Intro";
const lines = l.parseLrc(lrc);
eq(lines.length, 5, "timed lines only; tags dropped; sorted");
eq(lines[0].t, 0, "sorted by time");
eq(lines[1].text, "First line", "text trimmed");
eq(lines[1].t, 1.5, "seconds with hundredths");
eq(lines[4].t, 62.25, "minutes");
eq(lines[4].text, "Third [with brackets]", "brackets inside text kept");
eq(lines[3].text, "", "empty lines kept (a pause)");
// Several stamps on one line: repeated choruses.
eq(l.parseLrc("[00:01.00][00:10.00] Chorus").length, 2, "multiple stamps");

// The line at a position: the last one that started.
eq(l.lineAt(lines, 0.5), 0, "intro");
eq(l.lineAt(lines, 1.6), 1, "first");
eq(l.lineAt(lines, 5), 3, "the latest of equal stamps");
eq(l.lineAt(lines, 100), 4, "after the end: the last line");
eq(l.lineAt([], 3), -1, "no lyrics");
eq(l.lineAt([{ t: 5, text: "x" }], 1), -1, "before the first line");

// The lrclib query for a track.
eq(l.queryArgs({ title: "Song", artist: "Band", album: "LP", length: 201.4 }).join(" "),
   "--data-urlencode artist_name=Band --data-urlencode track_name=Song --data-urlencode duration=201", "query (no album: players disagree on it)");
eq(l.queryArgs({ title: "", artist: "Band" }), null, "no title, no query");
// What MPRIS titles carry that lrclib does not: "(Official Video)", "- Topic".
eq(l.cleanTitle("Song (Official Music Video)"), "Song", "video suffix");
eq(l.cleanTitle("Song [Lyrics]"), "Song", "bracketed");
eq(l.cleanArtist("Band - Topic"), "Band", "YouTube topic channel");
