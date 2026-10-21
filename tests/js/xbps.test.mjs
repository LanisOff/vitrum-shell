import { load, eq } from "./lib.mjs";
const x = load("xbps.js");
const j = JSON.stringify;

// `xbps-install -Mun`, as Void 0.60 prints it (taken from a Void container).
const check = [
  "ca-certificates-20250419+3.131.1_2 update x86_64 https://repo-default.voidlinux.org/current 192790 118379",
  "libpcre2-10.49_1 update x86_64 https://repo-default.voidlinux.org/current 2032768 597015",
  "runit-2.3.1_2 update x86_64 https://repo-default.voidlinux.org/current 1618152 414890",
  "fish-shell-4.9.3_1 install x86_64 https://repo-default.voidlinux.org/current 20282427 3968571",
  "old-thing-1.0_1 remove x86_64 https://repo-default.voidlinux.org/current 10 0",
  "",
].join("\n");
const installed = [
  "ii ca-certificates-20250419+3.131.1_1  Common CA certificates for SSL/TLS",
  "ii libpcre2-10.47_1                    Perl Compatible Regular Expressions (2nd version)",
  "ii runit-2.3.1_1                       UNIX init scheme with service supervision",
].join("\n");

eq(j(x.splitPkgver("libpcre2-10.49_1")), j({ name: "libpcre2", version: "10.49_1" }), "the last dash splits");
eq(j(x.splitPkgver("ca-certificates-20250419+3.131.1_2")), j({ name: "ca-certificates", version: "20250419+3.131.1_2" }), "dashes in the name");
eq(x.splitPkgver("nodash"), null, "not a pkgver");
eq(x.splitPkgver("name-1.0"), null, "no revision, not a pkgver");

eq(j(x.parseUpdates(check, installed)), j([
  { atom: "ca-certificates", from: "20250419+3.131.1_1", to: "20250419+3.131.1_2", kind: "update" },
  { atom: "libpcre2", from: "10.47_1", to: "10.49_1", kind: "update" },
  { atom: "runit", from: "2.3.1_1", to: "2.3.1_2", kind: "update" },
  { atom: "fish-shell", to: "4.9.3_1", kind: "new" },
]), "updates and new dependencies, with the versions they replace; removals left out");
eq(j(x.parseUpdates(check)[0]), j({ atom: "ca-certificates", to: "20250419+3.131.1_2", kind: "update" }), "without the installed list, no from");
eq(x.parseUpdates("").length, 0, "up to date");
eq(x.parseUpdates("ERROR: failed to open repository: https://repo-default.voidlinux.org/current: Input/output error").length, 0, "errors are not packages");

// Offline, xbps-install still exits 0; only stderr says so.
eq(x.checkFailed("ERROR: failed to open repository: https://repo-default.voidlinux.org/current: Input/output error\n"), true, "offline");
eq(x.checkFailed(check), false, "a good check");
eq(x.checkFailed(""), false, "nothing to update");

// The run, without a log: only ours, told by the file our update command
// writes ("started PID", then the exit code).
const idle = { running: false, ok: true, done: 0, total: 0, current: "", since: 0, started: 0, failed: "" };
let s = x.runState(idle, "started", true, 1000);
eq(s.running, true, "ours, its shell alive: running");
eq(s.started, 1000, "since now");
eq(x.runState(s, "started", true, 1010), s, "still running: unchanged");

let e = x.runState(s, "0", true, 1100);
eq(e.running, false, "the code is written: ended (the window still waits for Enter)");
eq(e.ok, true, "exit 0: fine");
eq(e.started, 1000, "keeps when it started");
eq(e.interrupted, undefined, "not cut off");
eq(x.runState(s, "0", false, 1100).ok, true, "and with the window closed after");
eq(x.runState(s, "1", false, 1100).ok, false, "a non-zero code: failed");

e = x.runState(s, "started", false, 1100);
eq(e.running, false, "the window closed mid-run: over");
eq(e.ok, false, "and not fine");
eq(e.interrupted, true, "cut off");
eq(x.runState(s, "", false, 1100).ok, false, "the file gone mid-run: not fine either");

// Root's runs we did not start (dnf makecache, dnf5 automatic) leave no file.
eq(x.runState(idle, "", false, 1000), idle, "a foreign run: nothing shows");
eq(x.runState(idle, "0", false, 1000), idle, "an earlier run's code: nothing shows");
eq(x.runState(idle, "started", false, 1000), idle, "an earlier run cut off before the shell started: nothing shows");
eq(x.runState(undefined, "", false, 1000).running, false, "no state yet");
