import { load, eq, readJson } from "./lib.mjs";
const u = load("vitrumupdate.js");
const due = (...a) => u.decide(...a).due;
const major = (...a) => u.decide(...a).major;

// Versions
eq(JSON.stringify(u.parseVersion("0.5.6")), "[0,5,6]", "three numbers");
eq(JSON.stringify(u.parseVersion(" 0.6.0\n")), "[0,6,0]", "the file's newline");
for (const bad of ["", "unknown", "0.6", "0.6.0.1", "v0.6.0", "0.6.0-rc1", "0.x.0", "1..0", null, undefined])
  eq(u.parseVersion(bad), null, `malformed ${JSON.stringify(bad)}`);
eq(u.isMajor("0.5.6", "0.6.0"), true, "second number grew");
eq(u.isMajor("0.9.9", "1.0.0"), true, "first number grew, second fell");
eq(u.isMajor("1.2.3", "2.0.0"), true, "first number grew");
eq(u.isMajor("0.5.6", "0.5.7"), false, "patch only");
eq(u.isMajor("0.5.6", "0.5.6"), false, "the same version");
eq(u.isMajor("0.6.0", "0.5.9"), false, "second number fell");
eq(u.isMajor("1.0.0", "0.9.0"), false, "first number fell, second grew");

// The commit rule
eq(due(4, 5, "0.5.6", "0.5.6"), false, "below the threshold");
eq(due(5, 5, "0.5.6", "0.5.6"), true, "at the threshold");
eq(due(6, 5, "0.5.6", "0.5.6"), true, "over the threshold");
eq(major(5, 5, "0.5.6", "0.5.6"), false, "a batch is not major");
eq(due(1, 1, "0.5.6", "0.5.6"), true, "threshold 1: any commit");
eq(due(1, 0, "0.5.6", "0.5.6"), true, "threshold 0: any commit");
eq(due(0, 0, "0.5.6", "0.5.6"), false, "threshold 0: still needs a commit");
eq(due(1, undefined, "0.5.6", "0.5.6"), true, "no threshold: any commit");

// A major version comes through below the threshold
eq(due(1, 5, "0.5.6", "0.6.0"), true, "major with one commit");
eq(major(1, 5, "0.5.6", "0.6.0"), true, "major with one commit is major");
eq(u.decide(1, 5, "0.5.6", " 0.6.0\n").version, "0.6.0", "names the remote version");
eq(due(1, 5, "0.9.9", "1.0.0"), true, "0.9.9 to 1.0.0");
eq(u.decide(1, 5, "0.9.9", "1.0.0").version, "1.0.0", "names 1.0.0");

// A patch bump is only commits
eq(due(2, 5, "0.5.6", "0.5.7"), false, "patch bump below the threshold");
eq(major(2, 5, "0.5.6", "0.5.7"), false, "patch bump is not major");
eq(u.decide(2, 5, "0.5.6", "0.5.7").version, "", "patch bump names no version");
eq(due(5, 5, "0.5.6", "0.5.7"), true, "patch bump at the threshold");

// Unreadable versions fall back to the commit rule
for (const [have, remote] of [["", "0.6.0"], ["0.5.6", ""], ["unknown", "0.6.0"], ["0.5.6", "garbage"], [undefined, undefined], ["0.5", "0.6.0"]]) {
  const name = `${JSON.stringify(have)} to ${JSON.stringify(remote)}`;
  eq(major(1, 5, have, remote), false, `${name}: no false major`);
  eq(due(1, 5, have, remote), false, `${name}: below the threshold stays quiet`);
  eq(due(5, 5, have, remote), true, `${name}: the count still decides`);
}

// A local build ahead of the remote
eq(major(1, 5, "0.6.0", "0.5.6"), false, "remote older: not major");
eq(due(1, 5, "0.6.0", "0.5.6"), false, "remote older: below the threshold stays quiet");
eq(due(1, 5, "1.0.0", "0.9.9"), false, "remote older across the first number");

// Nothing missing from the install, whatever VERSION says
eq(due(0, 5, "0.5.6", "0.6.0"), false, "no commits behind, higher version");
eq(major(0, 5, "0.5.6", "0.6.0"), false, "no commits behind is not major");
eq(due(undefined, 5, "0.5.6", "0.6.0"), false, "no count at all");

// Pulled but not installed: the commits count from the install (vitrum behind),
// so a cancelled update still tells
eq(major(3, 5, "0.5.6", "0.6.0"), true, "pulled and cancelled: still major");
eq(due(6, 5, "0.5.6", "0.5.7"), true, "pulled and cancelled: still a batch");

// The island: the version, or the count
eq(u.badge(u.decide(1, 5, "0.5.6", "0.6.0"), 1), "0.6.0", "island: major");
eq(u.badge(u.decide(7, 5, "0.5.6", "0.6.0"), 7), "0.6.0", "island: major over a batch");
eq(u.badge(u.decide(7, 5, "0.5.6", "0.5.7"), 7), "+7", "island: batch");

// The panel says the same reason
eq(u.title(u.decide(1, 5, "0.5.6", "0.6.0"), 1), "vitrum 0.6.0 is out", "panel: major");
eq(u.title(u.decide(7, 5, "0.5.6", "0.5.7"), 7), "7 new commits in vitrum", "panel: batch");
eq(u.title(u.decide(1, 5, "0.5.6", "0.5.7"), 1), "1 new commit in vitrum", "panel: one commit, below the threshold");
eq(u.title(u.decide(0, 5, "0.5.6", "0.6.0"), 0), "0 new commits in vitrum", "panel: nothing missing");

// The default the Settings slider and the shell both read
eq(readJson("shell/data/settings.defaults.json").updates.vitrum.threshold, 5, "default threshold");
