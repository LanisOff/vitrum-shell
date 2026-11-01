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

// What to ask lrclib: the exact track, its plainer form, then searches.
const asks = t => l.attempts(t).map(decodeURIComponent);
eq(asks({ title: "Song", artist: "Band", length: 201.4 }).join(" | "),
   "get?artist_name=Band&track_name=Song&duration=201 | search?track_name=Song&artist_name=Band | search?q=Band Song", "exact, then search (no album: players disagree on it)");
eq(asks({ title: "Song", artist: "Band" }).join(" | "), "search?track_name=Song&artist_name=Band | search?q=Band Song", "no length: searches only");
eq(asks({ title: "Song (feat. X) - Remastered 2011", artist: "A, B & C", length: 100 })[1],
   "get?artist_name=A&track_name=Song&duration=100", "the song itself, by its main artist");
eq(asks({ title: "Band - Song (Official Video)", artist: "Some Channel", length: 300 }).includes("search?track_name=Song&artist_name=Band"), true, "a video's title carries the artist");
eq(l.attempts({ title: "", artist: "Band" }).length, 0, "no title, nothing to ask");
eq(asks({ title: "Song", artist: "" }).join(" | "), "search?q=Song", "no artist: still searched");
eq(l.firstArtist("A feat. B"), "A", "main artist");
eq(l.firstArtist("Earth, Wind & Fire"), "Earth", "the split is a guess; the exact ask comes first");

// Answers: a line per ask; 503 is no answer about the song, 404 is.
const miss = l.parseAnswers('404\t{"code":404}\n200\t[]\n');
eq([miss.flaky, miss.cached, miss.items.length].join(), "false,false,1", "a clean miss");
eq(l.parseAnswers('503\t\n200\t[]\n').flaky, true, "503: not cached as missing");
eq(l.parseAnswers('000\t\n').flaky, true, "no connection likewise");
eq(l.parseAnswers('cached\t{"syncedLyrics":"[00:01.00] x"}\n').cached, true, "from the cache");

// The best answer.
const song = { title: "Song", artist: "Band", length: 200 };
const rec = (o) => Object.assign({ trackName: "Song", duration: 200, plainLyrics: "x", syncedLyrics: "[00:01.00] x" }, o);
eq(l.best([rec({ syncedLyrics: "", plainLyrics: "plain" }), rec({ duration: 204, syncedLyrics: "[00:01.00] a" }), rec({ duration: 201, syncedLyrics: "[00:01.00] b" })], song).syncedLyrics,
   "[00:01.00] b", "timed lines of the closest length");
eq(l.best([rec({ trackName: "Other tune" })], song), null, "a search's other songs are not this one");
eq(l.best([rec({ trackName: "Band - Song" })], song).syncedLyrics, "[00:01.00] x", "a title with the artist in it");
eq(l.best([rec({ duration: 260 })], song).syncedLyrics, "", "another cut: not sung along");
eq(l.best([rec({ duration: 260, plainLyrics: "" })], song).plainLyrics, "x", "...but its words are still shown");
eq(l.best([{ code: 404 }], song), null, "an error body");
eq(l.best([{ plainLyrics: "kept" }], song).plainLyrics, "kept", "what the cache kept has no title");
eq(l.cacheRecord({ syncedLyrics: "a", plainLyrics: "b" }, 5).checked, undefined, "timed lyrics stay");
eq(l.cacheRecord(null, 5).checked, 5, "nothing: asked again later");

// What MPRIS titles carry that lrclib does not: "(Official Video)", "- Topic".
eq(l.cleanTitle("Song (Official Music Video)"), "Song", "video suffix");
eq(l.cleanTitle("Song [Lyrics]"), "Song", "bracketed");
eq(l.cleanArtist("Band - Topic"), "Band", "YouTube topic channel");
