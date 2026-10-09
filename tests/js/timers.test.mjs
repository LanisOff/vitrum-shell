import { load, eq } from "./lib.mjs";
const t = load("timers.js");

// What the launcher understands as a timer.
eq(t.parse("5m"), 300, "minutes");
eq(t.parse("5 min"), 300, "minutes, spelled");
eq(t.parse("90s"), 90, "seconds");
eq(t.parse("1h30m"), 5400, "hours and minutes");
eq(t.parse("timer 10m"), 600, "with the word");
eq(t.parse("25"), null, "a bare number is maths, not a timer");
eq(t.parse("5 km"), null, "not time");
eq(t.parse("0m"), null, "nothing to count");
eq(t.parse("2 часа"), 7200, "russian hours");
eq(t.parse("10 минут"), 600, "russian minutes");

// Counting down.
eq(t.format(299.2), "5:00", "rounds up: never shows 0:00 while running");
eq(t.format(59), "0:59", "seconds");
eq(t.format(3723), "1:02:03", "hours");
eq(t.label(300), "5-minute timer", "label");
eq(t.label(90), "1 min 30 s timer", "label with seconds");
eq(t.label(5400), "1 h 30 min timer", "label with hours");

// Pomodoro: work, short break, … a long break after the fourth.
const p = { work: 25, short: 5, long: 15, rounds: 4 };
eq(JSON.stringify(t.pomodoroNext(null, p)), JSON.stringify({ phase: "work", round: 1, seconds: 1500 }), "starts with work");
eq(JSON.stringify(t.pomodoroNext({ phase: "work", round: 1 }, p)), JSON.stringify({ phase: "break", round: 1, seconds: 300 }), "short break");
eq(JSON.stringify(t.pomodoroNext({ phase: "break", round: 1 }, p)), JSON.stringify({ phase: "work", round: 2, seconds: 1500 }), "next round");
eq(JSON.stringify(t.pomodoroNext({ phase: "work", round: 4 }, p)), JSON.stringify({ phase: "long", round: 4, seconds: 900 }), "long break after four");
eq(JSON.stringify(t.pomodoroNext({ phase: "long", round: 4 }, p)), JSON.stringify({ phase: "work", round: 1, seconds: 1500 }), "and again");
