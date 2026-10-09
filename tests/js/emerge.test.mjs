import { load, eq } from "./lib.mjs";
const e = load("emerge.js");

const running = [
  "1000: Started emerge on: Oct 03, 2026 19:52:13",
  "1000:  *** emerge --ask=n @world",
  "1010:  >>> emerge (1 of 3) dev-libs/a-1.0 to /",
  "1070:  ::: completed emerge (1 of 3) dev-libs/a-1.0 to /",
  "1071:  >>> emerge (2 of 3) media-video/pipewire-1.6.8 to /",
  "1080:  === (2 of 3) Compiling/Merging (media-video/pipewire-1.6.8::/var/db/repos/gentoo/x.ebuild)",
].join("\n");
{
  const s = e.parseLog(running);
  eq(s.running, true, "no end yet: running");
  eq(s.done, 1, "one done");
  eq(s.total, 3, "of three");
  eq(s.current, "media-video/pipewire-1.6.8", "building now");
  eq(s.since, 1071, "since");
  eq(s.started, 1000, "the run started");
}
{
  const s = e.parseLog(running + "\n1200:  ::: completed emerge (2 of 3) media-video/pipewire-1.6.8 to /\n1201:  *** exiting successfully.\n1201:  *** terminating.");
  eq(s.running, false, "finished");
  eq(s.ok, true, "successfully");
}
{
  const s = e.parseLog(running + "\n1300:  *** exiting unsuccessfully with status '1'.\n1300:  *** terminating.");
  eq(s.ok, false, "failed");
  eq(s.failed, "media-video/pipewire-1.6.8", "what failed");
}
// Only the last run counts.
{
  const s = e.parseLog("1:  *** exiting unsuccessfully with status '1'.\n1:  *** terminating.\n" + running);
  eq(s.running, true, "the new run");
}
eq(e.parseLog("").running, false, "no log");

// Time left: the average so far times what is left.
// 71 s per package so far, two to go, 60 s into the current one.
eq(e.eta({ running: true, done: 1, total: 3, started: 1000, since: 1071 }, 1131), 82, "two left at ~71 s each");
eq(e.eta({ running: true, done: 0, total: 3, started: 1000, since: 1000 }, 1050), -1, "unknown before the first one finishes");
eq(e.formatEta(3700), "~1 h 2 min", "hours");
eq(e.formatEta(150), "~3 min", "minutes, rounded up");
eq(e.formatEta(-1), "", "unknown");

// emerge -puDN @world output → updates.
const pretend = [
  "[ebuild     U  ] sys-apps/systemd-utils-256::gentoo [255::gentoo] USE=\"udev\" 12 MiB",
  "[ebuild  N     ] dev-libs/newdep-1.0::gentoo  USE=\"-x\"",
  "[ebuild   R    ] media-libs/mesa-25.0::gentoo",
  "[ebuild     U ~] gui-apps/quickshell-0.3.2::guru [0.3.1::guru]",
  "Total: 4 packages (2 upgrades, 1 new, 1 reinstall), Size of downloads: 12 MiB",
].join("\n");
{
  const u = e.parseUpdates(pretend);
  eq(u.length, 3, "upgrades and new ones, not rebuilds");
  eq(JSON.stringify(u[0]), JSON.stringify({ atom: "sys-apps/systemd-utils", to: "256", from: "255", kind: "update" }), "an update");
  eq(u[1].kind, "new", "a new dependency");
  eq(u[2].atom, "gui-apps/quickshell", "keyworded update");
}
