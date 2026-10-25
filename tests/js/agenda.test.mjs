import { load, eq, ok } from "./lib.mjs";
const a = load("agenda.js");
const j = JSON.stringify;
const ics = (...lines) => lines.join("\r\n") + "\r\n";
const cal = (...events) => ics("BEGIN:VCALENDAR", "VERSION:2.0", "X-WR-CALNAME:Work", "X-APPLE-CALENDAR-COLOR:#3478F6FF", ...events.flat(), "END:VCALENDAR");
const ev = (...props) => ["BEGIN:VEVENT", ...props, "END:VEVENT"];
const local = (y, mo, d, h = 0, mi = 0) => new Date(y, mo - 1, d, h, mi).getTime();
const occ = (text, from, to) => a.occurrences(a.parseAll([{ id: "/c/work.ics", text }]), from, to);

// Lines: unfolded, parameters split, quoted colons kept, text unescaped.
eq(j(a.parseLine('DTSTART;TZID="Europe/Paris":20261026T090000')), j({ name: "DTSTART", params: { TZID: "Europe/Paris" }, value: "20261026T090000" }), "a parameter");
eq(a.unescapeText("Lunch\\, then a walk\\nby the river\\; ok"), "Lunch, then a walk\nby the river; ok", "unescaped");
{
  const c = a.parseCalendar(cal(ev("UID:1", "SUMMARY:A very long", " title that folds", "DTSTART:20261026T090000")));
  eq(c.events[0].title, "A very longtitle that folds", "unfolded");
  eq(c.name, "Work", "calendar name");
  eq(c.color, "#3478F6FF", "calendar colour");
}
eq(a.parseDuration("P1DT2H30M"), (26 * 60 + 30) * 60000, "duration");
eq(a.parseDuration("PT15M"), 15 * 60000, "minutes");
eq(a.parseDuration("P1W"), 7 * 86400000, "weeks");
eq(a.nthWeekday(2026, 2, 0, -1), 29, "last Sunday of March 2026");
eq(a.nthWeekday(2026, 9, 0, -1), 25, "last Sunday of October 2026");
eq(a.nthWeekday(2026, 10, 4, 4), 26, "fourth Thursday of November 2026");

// The reader's dump: calendars with their colour and name, the signature.
{
  const d = a.splitDump("\x1eSIG 123 45\n\x1eCAL /h/cals/work.ics\nBEGIN:VCALENDAR\nEND:VCALENDAR\n\x1eCAL /h/cals/home\n\x1eMETA color #ff8800\n\x1eMETA name Home\nBEGIN:VCALENDAR\n");
  eq(d.sig, "123 45", "signature");
  eq(d.calendars.length, 2, "two calendars");
  eq(d.calendars[1].color, "#ff8800", "folder colour");
  eq(d.calendars[1].name, "Home", "folder name");
  const p = a.parseAll(d.calendars);
  eq(p[0].name, "work", "no name: the file's");
  eq(p[1].name, "Home", "the folder's name wins");
  ok(p[0].hue >= 0 && p[0].hue < 360, "a fallback hue");
  eq(a.parseAll([{ id: "x", text: cal() }])[0].color, "#3478F6", "Apple's #rrggbbaa → #rrggbb");
}

// Single events: timed (floating = local), UTC, all-day; ended ones dropped by the agenda.
{
  const text = cal(
    ev("UID:a", "SUMMARY:Stand-up", "DTSTART:20261026T093000", "DTEND:20261026T094500"),
    ev("UID:b", "SUMMARY:Call", "DTSTART:20261026T120000Z", "DURATION:PT1H"),
    ev("UID:c", "SUMMARY:Holiday", "DTSTART;VALUE=DATE:20261027", "DTEND;VALUE=DATE:20261029"),
    ev("UID:d", "SUMMARY:Cancelled", "STATUS:CANCELLED", "DTSTART:20261026T150000"),
    ev("UID:e", "SUMMARY:Next week", "DTSTART:20261102T100000"));
  const o = occ(text, local(2026, 10, 26), local(2026, 10, 28));
  eq(j(o.map(x => x.title).sort()), j(["Call", "Holiday", "Stand-up"]), "in the window, the cancelled one left out");
  const call = o.find(x => x.title === "Call");
  eq(call.start, Date.UTC(2026, 9, 26, 12), "UTC time");
  eq(call.end - call.start, 3600000, "duration");
  const hol = o.find(x => x.title === "Holiday");
  eq(hol.allDay, true, "all day");
  eq(hol.end, local(2026, 10, 29), "two days long");
  const ag = a.agenda(o, local(2026, 10, 26, 10, 0), 2, true);
  eq(ag.length, 2, "two days");
  eq(ag[0].start, local(2026, 10, 26), "today first");
  ok(!ag[0].items.some(x => x.title === "Stand-up"), "the stand-up is over by ten");
  eq(ag[1].items[0].title, "Holiday", "tomorrow: the holiday");
  eq(ag[1].items[0].kind, "allday", "as all day");
  eq(a.agenda(o, local(2026, 10, 26, 10, 0), 2, false)[1].items.length, 0, "all-day ones hidden on request");
  eq(a.agenda([], local(2026, 10, 26, 10, 0), 3, true).length, 3, "empty days kept");
}

// Events across midnight: "until" the next day, "through" a day in the middle.
{
  const o = occ(cal(ev("UID:n", "SUMMARY:Night shift", "DTSTART:20261026T220000", "DTEND:20261028T060000")), local(2026, 10, 26), local(2026, 10, 29));
  const ag = a.agenda(o, local(2026, 10, 26, 8), 3, true);
  eq(j(ag.map(d => d.items[0] && d.items[0].kind)), j(["start", "through", "until"]), "start, through, until");
  eq(ag[2].items[0].at, local(2026, 10, 28, 6), "until its end");
}

// Repeats.
{
  const weekly = cal(ev("UID:w", "SUMMARY:Gym", "DTSTART:20260105T180000", "DTEND:20260105T190000", "RRULE:FREQ=WEEKLY;BYDAY=MO,TH"));
  const o = occ(weekly, local(2026, 10, 26), local(2026, 11, 2));
  eq(j(o.map(x => new Date(x.start).getDate())), j([26, 29]), "weekly on Monday and Thursday");
  eq(new Date(o[0].start).getHours(), 18, "at its time");
  const counted = cal(ev("UID:c", "SUMMARY:Course", "DTSTART:20261001T100000", "RRULE:FREQ=WEEKLY;COUNT=4"));
  eq(occ(counted, local(2026, 10, 1), local(2026, 12, 1)).length, 4, "COUNT");
  const until = cal(ev("UID:u", "SUMMARY:Daily", "DTSTART:20261020T080000", "RRULE:FREQ=DAILY;UNTIL=20261027T235959Z"));
  eq(occ(until, local(2026, 10, 25), local(2026, 11, 5)).length, 3, "UNTIL: 25, 26, 27");
  const every2 = cal(ev("UID:e", "SUMMARY:Bins", "DTSTART;VALUE=DATE:20261001", "RRULE:FREQ=DAILY;INTERVAL=2"));
  eq(j(occ(every2, local(2026, 10, 25), local(2026, 10, 30)).map(x => new Date(x.start).getDate())), j([25, 27, 29]), "every other day");
  const old = cal(ev("UID:o", "SUMMARY:Pills", "DTSTART:20100101T090000", "RRULE:FREQ=DAILY"));
  eq(occ(old, local(2026, 10, 26), local(2026, 10, 28)).length, 2, "a daily rule from 2010 still reaches today");
  const monthly = cal(ev("UID:m", "SUMMARY:Rent", "DTSTART;VALUE=DATE:20260131", "RRULE:FREQ=MONTHLY"));
  eq(j(occ(monthly, local(2026, 1, 1), local(2026, 6, 1)).map(x => new Date(x.start).getMonth() + 1)), j([1, 3, 5]), "the 31st: only months that have one");
  const lastFri = cal(ev("UID:l", "SUMMARY:Review", "DTSTART:20260130T150000", "RRULE:FREQ=MONTHLY;BYDAY=-1FR"));
  eq(new Date(occ(lastFri, local(2026, 10, 1), local(2026, 11, 1))[0].start).getDate(), 30, "last Friday of October 2026");
  const bday = cal(ev("UID:y", "SUMMARY:Birthday", "DTSTART;VALUE=DATE:19900227", "RRULE:FREQ=YEARLY"));
  eq(occ(bday, local(2026, 2, 1), local(2026, 3, 1)).length, 1, "yearly");
  const thanks = cal(ev("UID:t", "SUMMARY:Thanksgiving", "DTSTART;VALUE=DATE:20201126", "RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=4TH"));
  eq(new Date(occ(thanks, local(2026, 11, 1), local(2026, 12, 1))[0].start).getDate(), 26, "fourth Thursday of November");
}

// Exceptions: EXDATE skips one; a RECURRENCE-ID moves one.
{
  const text = cal(
    ev("UID:s", "SUMMARY:Sync", "DTSTART:20261019T100000", "DTEND:20261019T103000", "RRULE:FREQ=DAILY", "EXDATE:20261027T100000"),
    ev("UID:s", "SUMMARY:Sync (moved)", "RECURRENCE-ID:20261028T100000", "DTSTART:20261028T140000", "DTEND:20261028T143000"));
  const o = occ(text, local(2026, 10, 26), local(2026, 10, 30));
  eq(j(o.map(x => new Date(x.start).getDate() + " " + new Date(x.start).getHours())), j(["26 10", "28 14", "29 10"]), "skipped and moved");
}

// Time zones from VTIMEZONE: 09:00 in New York is 13:00 UTC in summer, 14:00 in winter.
{
  const tz = ["BEGIN:VTIMEZONE", "TZID:America/New_York",
    "BEGIN:DAYLIGHT", "TZOFFSETFROM:-0500", "TZOFFSETTO:-0400", "DTSTART:20070311T020000", "RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU", "END:DAYLIGHT",
    "BEGIN:STANDARD", "TZOFFSETFROM:-0400", "TZOFFSETTO:-0500", "DTSTART:20071104T020000", "RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU", "END:STANDARD",
    "END:VTIMEZONE"];
  const text = cal(tz, ev("UID:z", "SUMMARY:NY call", "DTSTART;TZID=America/New_York:20261026T090000", "DURATION:PT1H", "RRULE:FREQ=WEEKLY"));
  const o = occ(text, local(2026, 10, 25), local(2026, 11, 10));
  eq(o[0].start, Date.UTC(2026, 9, 26, 13), "summer time: UTC−4");
  eq(o[2].start, Date.UTC(2026, 10, 9, 14), "after the change: UTC−5, same wall time");
  const unknown = cal(ev("UID:q", "SUMMARY:Somewhere", "DTSTART;TZID=Mars/Olympus:20261026T090000"));
  eq(occ(unknown, local(2026, 10, 26), local(2026, 10, 27))[0].start, local(2026, 10, 26, 9), "an unknown zone: local time");
}

// Order: by start; all-day ones first on a day.
{
  const text = cal(ev("UID:1", "SUMMARY:B", "DTSTART:20261026T080000"), ev("UID:2", "SUMMARY:A", "DTSTART;VALUE=DATE:20261026"));
  const ag = a.agenda(occ(text, local(2026, 10, 26), local(2026, 10, 27)), local(2026, 10, 26, 7), 1, true);
  eq(j(ag[0].items.map(x => x.title)), j(["A", "B"]), "all day, then the morning");
}
// Garbage in: no throw, nothing out.
eq(occ("not a calendar\nBEGIN:VEVENT\nDTSTART:garbage\nEND:VEVENT", 0, Date.now()).length, 0, "garbage");
