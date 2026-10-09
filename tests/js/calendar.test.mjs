import { load, eq } from "./lib.mjs";
const c = load("calendar.js");

// "14:30 Dentist" → a timed event, an hour long; "Trip" → all day.
eq(JSON.stringify(c.parseQuick("14:30 Dentist")), JSON.stringify({ title: "Dentist", time: "14:30", minutes: 60 }), "timed");
eq(JSON.stringify(c.parseQuick("9:05 Standup 15m")), JSON.stringify({ title: "Standup", time: "09:05", minutes: 15 }), "with a length");
eq(JSON.stringify(c.parseQuick("Trip to Riga")), JSON.stringify({ title: "Trip to Riga", time: "", minutes: 0 }), "all day");
eq(c.parseQuick("   "), null, "nothing");
eq(c.parseQuick("25:00 x"), null, "not a time");

const ev = [
  { uid: "a", title: "Dentist", start: "2026-10-06 14:30", end: "2026-10-06 15:15", allDay: false },
  { uid: "b", title: "Trip", start: "2026-10-07", end: "2026-10-09", allDay: true },
];
eq(c.on(ev, new Date(2026, 9, 6)).map(e => e.uid).join(), "a", "a day's events");
eq(c.on(ev, new Date(2026, 9, 8)).map(e => e.uid).join(), "b", "inside a several-day event");
eq(c.on(ev, new Date(2026, 9, 10)).length, 0, "after it");
eq(c.ymd(new Date(2026, 0, 5)), "2026-01-05", "date key");

// Reminders: ten minutes before, once.
eq(c.due(ev[0], new Date(2026, 9, 6, 14, 20, 10), 10), true, "ten minutes before");
eq(c.due(ev[0], new Date(2026, 9, 6, 14, 10), 10), false, "too early");
eq(c.due(ev[0], new Date(2026, 9, 6, 14, 31), 10), false, "already started");
eq(c.due(ev[1], new Date(2026, 9, 7, 8, 0), 10), false, "all-day events do not ring");
eq(c.timeOf(ev[0]), "14:30", "time shown");
