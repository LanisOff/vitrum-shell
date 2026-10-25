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

// chrome(amb, leave): the quiet screen recedes, the unlock takes it out
eq(l.QUIET_OPACITY, 0.35, "quiet opacity");
eq(l.chrome(0, 0), 1, "at rest, all of it");
eq(Math.round(l.chrome(1, 0) * 100) / 100, 0.35, "quiet: recedes to 0.35");
eq(l.chrome(1, 1), 0, "unlocking: gone");
eq(l.chrome(0, 1), 0, "unlocking from rest: gone");
eq(l.chrome(5, -1), l.chrome(1, 0), "clamped");

// rise(enter, order, last): staggered, and every block in place at the end
eq(l.rise(0, 0, 8), 0, "nothing before the start");
eq(l.rise(1, 0, 8), 1, "the first block in place");
eq(l.rise(1, 8, 8), 1, "the last block in place too (none stuck short of it)");
eq(l.rise(0.2, 8, 8), 0, "the last one waits its turn");
eq(l.rise(0.3, 1, 8) > l.rise(0.3, 2, 8), true, "one after another");
let mono = true, prev = -1;
for (let e = 0; e <= 1.0001; e += 0.01) { const v = l.rise(e, 3, 8); if (v < prev - 1e-9 || v > 1) mono = false; prev = v; }
eq(mono, true, "never overshoots, never goes back");

// faceCandidates(home, user)
eq(l.faceCandidates("/home/lanis", "lanis").join(" "), "/home/lanis/.face /home/lanis/.face.icon /var/lib/AccountsService/icons/lanis", "the picture: ~/.face, ~/.face.icon, AccountsService");
eq(l.faceCandidates("", "").length, 0, "nothing to look at");

// capsLockOn(text): any keyboard's LED lit
eq(l.capsLockOn("0\n0\n"), false, "all dark");
eq(l.capsLockOn("0\n1\n"), true, "one keyboard lit");
eq(l.capsLockOn("255"), true, "max brightness");
eq(l.capsLockOn(""), false, "no LEDs at all");
eq(l.capsLockOn("cat: no such file"), false, "an error is not on");

// networkLabel / networkIcon
eq(l.networkLabel("wired", "enp12s0", true), "Ethernet", "a cable says Ethernet, not the interface");
eq(l.networkLabel("wifi", "Home", true), "Home", "Wi-Fi: the network");
eq(l.networkLabel("wifi", "", true), "Wi-Fi", "Wi-Fi without a name");
eq(l.networkLabel("none", "", false), "Offline", "offline");
eq(l.networkIcon("wired", 1, true), "ethernet", "cable icon");
eq(l.networkIcon("wifi", 0.9, true), "wifi-high", "strong Wi-Fi");
eq(l.networkIcon("wifi", 0.2, true), "wifi-low", "weak Wi-Fi");
eq(l.networkIcon("none", 0, false), "network-off", "offline icon");

// powerLabel(action, armed)
eq(l.powerLabel("suspend", false), "Sleep", "sleep");
eq(l.powerLabel("reboot", false), "Restart", "restart");
eq(l.powerLabel("reboot", true), "Again to restart", "armed restart");
eq(l.powerLabel("poweroff", true), "Again to power off", "armed power off");
eq(l.powerLabel("suspend", true), "Sleep", "sleep is never armed");
