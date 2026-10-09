import { load, eq } from "./lib.mjs";
const l = load("lock.js");

// greeting(hour, name)
eq(l.greeting(8, "Lanis"), "Good morning, Lanis", "morning");
eq(l.greeting(5, "Lanis"), "Good morning, Lanis", "morning starts at 5");
eq(l.greeting(12, "Lanis"), "Good afternoon, Lanis", "afternoon");
eq(l.greeting(18, "Lanis"), "Good evening, Lanis", "evening");
eq(l.greeting(23, "Lanis"), "Good night, Lanis", "late");
eq(l.greeting(3, "Lanis"), "Good night, Lanis", "small hours");
eq(l.greeting(9, ""), "Good morning", "no name, no comma");

// firstName(realName, user): what the greeting calls you
eq(l.firstName("Lanis Doe", "lanis"), "Lanis", "first word of the real name");
eq(l.firstName("Lanis,,,", "lanis"), "Lanis", "GECOS commas dropped");
eq(l.firstName("", "lanis"), "Lanis", "user name, capitalised");
eq(l.firstName("", ""), "", "nothing at all");
eq(l.firstName("lanis", "lanis"), "Lanis", "a lowercase real name gets a capital");
eq(l.initial("lanis"), "L", "initial");
eq(l.initial(""), "?", "initial of nothing");

// lockNotifications(history, since, mode, max)
const t0 = new Date(2026, 9, 2, 10, 0).getTime();
const n = (app, summary, body, min, icon = "") => ({ appName: app, appIcon: icon, summary, body, time: new Date(t0 + min * 60000) });
const hist = [  // newest first, as Notifs keeps it
  n("Telegram", "Anna", "<b>see</b> you", 9, "telegram"),
  n("Firefox", "Download done", "file.iso", 8),
  n("Telegram", "Bob", "hi", 7, "telegram"),
  n("Mail", "Invoice", "pay", 6),
  n("Steam", "Sale", "50%", 5),
  n("Old", "before lock", "x", -5),
];
let g = l.lockNotifications(hist, t0, "apps", 3);
eq(g.length, 3, "at most three groups");
eq(g.map(x => x.app).join(","), "Telegram,Firefox,Mail", "grouped by app, newest first");
eq(g[0].count, 2, "count per app");
eq(g[0].icon, "telegram", "icon kept");
eq(g[0].title, "", "apps mode hides the title");
eq(g[0].body, "", "apps mode hides the body");
g = l.lockNotifications(hist, t0, "full", 3);
eq(g[0].title, "Anna", "full: latest title");
eq(g[0].body, "see you", "full: body without markup");
eq(JSON.stringify(g[0].items), JSON.stringify([{ title: "Anna", body: "see you" }, { title: "Bob", body: "hi" }]), "full: every one in the group, newest first, to expand");
eq(l.lockNotifications(hist, t0, "apps", 3)[0].items.length, 0, "apps mode: nothing to expand");
const many = [];
for (let i = 0; i < 9; i++) many.push(n("Chat", "m" + i, "", 9 - i * 0.1));
eq(l.lockNotifications(many, t0, "full", 3)[0].items.length, 5, "at most five to expand");
eq(l.lockNotifications(many, t0, "full", 3)[0].count, 9, "but all counted");
eq(l.lockNotifications(hist, t0, "off", 3).length, 0, "off shows nothing");
eq(l.lockNotifications(hist, t0 + 100 * 60000, "apps", 3).length, 0, "nothing since the lock");
eq(l.lockNotifications(hist, t0, "apps", 10).some(x => x.app === "Old"), false, "older than the lock left out");
eq(l.lockNotifications([], t0, "full", 3).length, 0, "empty history");

// ambientActive(now, lastInput, seconds, typing)
eq(l.ambientActive(20000, 9000, 10, false), true, "quiet for 11 s");
eq(l.ambientActive(18000, 9000, 10, false), false, "quiet for 9 s");
eq(l.ambientActive(99000, 0, 0, false), false, "0 turns it off");
eq(l.ambientActive(99000, 0, 10, true), false, "never while a password is half typed");

// powerPress(pending, action, now, windowMs): restart and power off need a second press
let p = l.powerPress(null, "suspend", 1000, 3000);
eq(p.fire, "suspend", "suspend at once"); eq(p.pending, null, "nothing pending after suspend");
p = l.powerPress(null, "reboot", 1000, 3000);
eq(p.fire, "", "first press of restart only arms it"); eq(p.pending.action, "reboot", "restart armed");
p = l.powerPress(p.pending, "reboot", 2500, 3000);
eq(p.fire, "reboot", "second press within the window"); eq(p.pending, null, "disarmed after firing");
p = l.powerPress({ action: "reboot", at: 1000 }, "reboot", 5000, 3000);
eq(p.fire, "", "too late: arms again"); eq(p.pending.at, 5000, "re-armed now");
p = l.powerPress({ action: "reboot", at: 1000 }, "poweroff", 1500, 3000);
eq(p.fire, "", "another action does not confirm the first"); eq(p.pending.action, "poweroff", "the new one is armed");

// formatDuration(seconds)
eq(l.formatDuration(7), "0:07", "seconds");
eq(l.formatDuration(225), "3:45", "minutes");
eq(l.formatDuration(3723), "1:02:03", "hours");
eq(l.formatDuration(-1), "0:00", "negative");
eq(l.formatDuration(NaN), "0:00", "NaN");

// lockBackground(path, poster): an image as it is; a video's poster frame
eq(l.lockBackground("/w/forest.jpg", "/c/poster.png"), "/w/forest.jpg", "image");
eq(l.lockBackground("/w/rain.MP4", "/c/poster.png"), "/c/poster.png", "video → poster");
eq(l.lockBackground("/w/rain.webm", ""), "", "video without a poster → nothing");
eq(l.lockBackground("", "/c/poster.png"), "", "no wallpaper");
