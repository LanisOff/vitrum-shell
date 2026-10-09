import { load, eq } from "./lib.mjs";
const w = load("wallpaper.js");
const j = JSON.stringify;

eq(w.isVideo("/a/b.MP4"), true, "video by extension, any case");
eq(w.isVideo("/a/b.webm"), true, "webm");
eq(w.isVideo("/a/b.jpg"), false, "image");
eq(w.isVideo(""), false, "nothing");

// Per-output path wins over the shared one; "~" expands.
const s = { path: "~/w/a.jpg", perOutput: { "DP-1": "/x/b.png" } };
eq(w.pathFor(s, "DP-1", "/home/u"), "/x/b.png", "per output");
eq(w.pathFor(s, "HDMI-A-1", "/home/u"), "/home/u/w/a.jpg", "shared, expanded");
eq(w.pathFor({ path: "", perOutput: {} }, "DP-1", "/home/u"), "", "none");

// awww: the transition, from where it was asked (top-left origin) or the centre.
eq(j(w.awwwArgs("/p.jpg", "DP-1", "grow", { x: 100, y: 50 }, 0.9)),
   j(["awww", "img", "/p.jpg", "-o", "DP-1", "-t", "grow", "--transition-pos", "100,50", "--invert-y", "--transition-duration", "0.9", "--transition-fps", "60"]), "grow from a point");
eq(j(w.awwwArgs("/p.jpg", "DP-1", "grow", null, 0.9)).indexOf("center") > 0, true, "grow from the centre");
eq(j(w.awwwArgs("/p.jpg", "DP-1", "fade", null, 0.9).slice(5, 7)), j(["-t", "fade"]), "fade");
eq(j(w.awwwArgs("/p.jpg", "DP-1", "none", null, 0.9).slice(5, 7)), j(["-t", "none"]), "none");
eq(j(w.awwwArgs("/p.jpg", "DP-1", "bogus", null, 0.9).slice(5, 7)), j(["-t", "grow"]), "unknown → grow");

// mpvpaper: silent, looping, with an IPC socket for pausing.
eq(j(w.mpvArgs("/v.mp4", "DP-1", "/run/s")),
   j(["mpvpaper", "-o", "no-audio loop hwdec=auto input-ipc-server=/run/s", "DP-1", "/v.mp4"]), "mpvpaper");
eq(w.mpvPause(true), '{"command":["set_property","pause",true]}\n', "pause message");

// Covered: the visible columns fill the output (fullscreen or side by side).
const out = { w: 1920, h: 1080 };
eq(w.covered([], out, 40), false, "empty workspace");
eq(w.covered([{ col: 1, w: 1920, h: 1040 }], out, 40), true, "one full-size column");
eq(w.covered([{ col: 1, w: 960, h: 1040 }], out, 40), false, "half the width");
eq(w.covered([{ col: 1, w: 960, h: 1040 }, { col: 2, w: 960, h: 1040 }], out, 40), true, "two halves");
eq(w.covered([{ col: 1, w: 960, h: 500 }, { col: 1, w: 960, h: 540 }, { col: 2, w: 960, h: 1040 }], out, 40), true, "stacked tiles fill a column");
eq(w.covered([{ col: 1, w: 1920, h: 600 }], out, 40), false, "short column");
eq(w.covered([{ col: 1, w: 1920, h: 1080, floating: true }], out, 40), false, "floating windows do not count");

// Parallax: first workspace at the top of the taller image, last at the bottom.
eq(w.parallaxOffset(0, 5, 100), 0, "first");
eq(w.parallaxOffset(4, 5, 100), -100, "last");
eq(w.parallaxOffset(2, 5, 100), -50, "middle");
eq(w.parallaxOffset(0, 1, 100), 0, "single workspace");

// Next / previous in a folder, wrapping; unknown current → first.
const files = ["/w/a.jpg", "/w/b.png", "/w/c.mp4"];
eq(w.step(files, "/w/b.png", 1), "/w/c.mp4", "next");
eq(w.step(files, "/w/c.mp4", 1), "/w/a.jpg", "wraps");
eq(w.step(files, "/w/a.jpg", -1), "/w/c.mp4", "previous wraps");
eq(w.step(files, "/elsewhere.jpg", 1), "/w/a.jpg", "unknown → first");
eq(w.step([], "/w/a.jpg", 1), "", "empty folder");

// Day and night versions of one wallpaper: name-day.jpg ↔ name-night.jpg.
{
  const w = load("wallpaper.js");
  eq(w.counterpart("/w/forest-day.jpg", false), "/w/forest-night.jpg", "to night");
  eq(w.counterpart("/w/forest-night.jpg", true), "/w/forest-day.jpg", "to day");
  eq(w.counterpart("/w/forest_Night.png", true), "/w/forest_Day.png", "underscore, case kept");
  eq(w.counterpart("/w/forest-day.jpg", true), null, "already day");
  eq(w.counterpart("/w/forest.jpg", false), null, "no pair");
  eq(w.counterpart("", false), null, "nothing");
}

// halves(path): the day and the night picture of a pair, or the one picture for both.
eq(JSON.stringify(w.halves("/w/lake-day.jpg")), JSON.stringify({ day: "/w/lake-day.jpg", night: "/w/lake-night.jpg" }), "a day picture and its night");
eq(JSON.stringify(w.halves("/w/Lake_Night.png")), JSON.stringify({ day: "/w/Lake_Day.png", night: "/w/Lake_Night.png" }), "a night picture and its day, same case");
eq(JSON.stringify(w.halves("/w/lake.jpg")), JSON.stringify({ day: "/w/lake.jpg", night: "/w/lake.jpg" }), "no pair: the one for both");
eq(w.halves(""), null, "no wallpaper");
