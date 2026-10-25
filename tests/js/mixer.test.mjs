import { load, eq } from "./lib.mjs";
const m = load("mixer.js");
const j = JSON.stringify;

const rows = m.group([
  { app: "Firefox", icon: "firefox", volume: 0.4, muted: false },
  { app: "Spotify", icon: "spotify", volume: 0.8, muted: true },
  { app: "firefox", icon: "", volume: 0.7, muted: true },
  null,
  { app: "", icon: "", volume: 1, muted: false }
]);
eq(rows.length, 3, "one row per app (names in any case)");
eq(rows[0].app, "Firefox", "the first stream names the row");
eq(j(rows[0].members), j([0, 2]), "members by index");
eq(rows[0].volume, 0.7, "the loudest stream's volume");
eq(rows[0].muted, false, "muted only when every stream is");
eq(rows[1].muted, true, "one muted stream: muted");
eq(rows[2].app, "An app", "no name: a stand-in");
eq(m.group([]).length, 0, "nothing playing");
eq(m.group(null).length, 0, "no list");

eq(j(m.fit(2, 100, 30, 6)), j({ rows: 2, more: 0 }), "fit: all of them");
eq(j(m.fit(5, 140, 30, 6)), j({ rows: 3, more: 2 }), "fit: one row makes way for 'and 2 more'");
eq(j(m.fit(3, 102, 30, 6)), j({ rows: 3, more: 0 }), "fit: exactly");
eq(j(m.fit(4, 20, 30, 6)), j({ rows: 0, more: 4 }), "fit: no room");
