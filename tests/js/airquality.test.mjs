import { load, eq, ok } from "./lib.mjs";
const q = load("airquality.js");

// The European AQI's bands: 0–20 good … 80–100 very poor, past 100 extremely poor.
eq(q.level(0), 0, "0: good");
eq(q.level(20), 0, "20: still good");
eq(q.level(20.5), 1, "past 20: fair");
eq(q.level(55), 2, "moderate");
eq(q.level(75), 3, "poor");
eq(q.level(100), 4, "very poor");
eq(q.level(140), 5, "extremely poor");
eq(q.level(null), -1, "no reading");
eq(q.level(undefined), -1, "undefined: no reading");
eq(q.level(-3), -1, "negative: no reading");
// Particles have their own bands.
eq(q.level(12, "pm2_5"), 1, "PM2.5 12: fair");
eq(q.level(30, "pm2_5"), 3, "PM2.5 30: poor");
eq(q.level(45, "pm10"), 2, "PM10 45: moderate");
eq(q.level(200, "pm10"), 5, "PM10 200: extremely poor");
eq(q.label(0), "Good", "label");
eq(q.label(5), "Extremely poor", "the last label");
eq(q.label(-1), "—", "no label");
ok(q.HUES.length === q.LEVELS.length, "a hue per level");
eq(q.fraction(50), 0.5, "fraction of the scale");
eq(q.fraction(180), 1, "full past very poor");
eq(q.fraction(null), 0, "nothing: empty");
eq(q.fraction(37.5, "pm2_5"), 0.5, "PM2.5 scale");

ok(q.query(56.85, 60.61).indexOf("latitude=56.85&longitude=60.61") > 0, "query: the place");
ok(q.query(1, 2).indexOf("current=european_aqi,pm2_5,pm10") > 0, "query: what is asked");

const reply = JSON.stringify({ latitude: 56.8, current: { time: "2026-10-25T12:00", interval: 3600, european_aqi: 24, pm2_5: 8.4, pm10: 14.1 } });
const p = q.parse(reply);
eq(p.aqi, 24, "parse: AQI"); eq(p.pm25, 8.4, "parse: PM2.5"); eq(p.pm10, 14.1, "parse: PM10"); eq(p.time, "2026-10-25T12:00", "parse: time");
eq(q.parse(JSON.stringify({ current: { european_aqi: null, pm2_5: 3 } })).aqi, null, "parse: a null stays null");
ok(!!q.parse("<html>").error, "parse: not JSON");
eq(q.parse(JSON.stringify({ error: true, reason: "Latitude must be in range" })).error, "Latitude must be in range", "parse: the API's reason");
ok(!!q.parse(JSON.stringify({ current: {} })).error, "parse: no readings at all");
ok(!!q.parse("null").error, "parse: null");

eq(q.stale(0, 1000, 500), true, "stale: never asked");
eq(q.stale(1000, 1400, 500), false, "stale: fresh");
eq(q.stale(1000, 1500, 500), true, "stale: old enough");
