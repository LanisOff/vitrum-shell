import { load, eq } from "./lib.mjs";
const s = load("sun.js");
const at = (h, m) => new Date(2026, 9, 1, h, m);
eq(s.isDay(at(12, 0), at(7, 10), at(18, 40)), true, "noon is day");
eq(s.isDay(at(21, 0), at(7, 10), at(18, 40)), false, "night");
eq(s.isDay(at(12, 0), null, null, { light: "07:00", dark: "19:30" }), true, "schedule day");
eq(s.isDay(at(23, 0), null, null, { light: "07:00", dark: "19:30" }), false, "schedule night");
eq(s.isDay(at(2, 0), null, null, { light: "22:00", dark: "06:00" }), true, "schedule across midnight");
eq(s.isDay(at(12, 0), new Date("x"), null, { light: "07:00", dark: "19:30" }), true, "invalid sunrise → schedule");
