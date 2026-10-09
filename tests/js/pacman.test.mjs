import { load, eq } from "./lib.mjs";
const p = load("pacman.js");
const j = JSON.stringify;

const log = [
  "[2026-10-04T10:00:00+0300] [PACMAN] Running 'pacman -Syu'",
  "[2026-10-04T10:00:01+0300] [PACMAN] synchronizing package lists",
  "[2026-10-04T10:00:20+0300] [ALPM] transaction started",
  "[2026-10-04T10:00:22+0300] [ALPM] upgraded linux (6.9.1.arch1-1 -> 6.9.2.arch1-1)",
  "[2026-10-04T10:00:30+0300] [ALPM] installed foo (1.0-1)",
].join("\n");

let s = p.parseLog(log);
eq(s.running, true, "a transaction under way");
eq(s.done, 2, "two packages done");
eq(s.current, "foo", "the last one");
eq(s.started, Date.parse("2026-10-04T10:00:20+03:00") / 1000, "started when the transaction did");
eq(s.since, Date.parse("2026-10-04T10:00:30+03:00") / 1000, "the last step's time");

s = p.parseLog(log + "\n[2026-10-04T10:00:40+0300] [ALPM] removed bar (2.0-1)\n[2026-10-04T10:00:41+0300] [ALPM] transaction completed");
eq(s.running, false, "completed");
eq(s.ok, true, "and fine");
eq(s.done, 3, "removals count too");

s = p.parseLog(log + "\n[2026-10-04T10:00:41+0300] [ALPM] transaction failed");
eq(s.ok, false, "failed");
eq(s.failed, "foo", "where it stopped");

// A new transaction starts the count again.
s = p.parseLog(log + "\n[2026-10-04T10:00:41+0300] [ALPM] transaction completed\n[2026-10-04T11:00:00+0300] [ALPM] transaction started");
eq(s.running, true, "the next one");
eq(s.done, 0, "counted afresh");

eq(p.parseLog("").running, false, "empty log");

// checkupdates (and pacman -Qu) → updates.
eq(j(p.parseUpdates("linux 6.9.1.arch1-1 -> 6.9.2.arch1-1\nfoo 1.0-1 -> 1.1-1\n\ngarbage")),
   j([{ atom: "linux", from: "6.9.1.arch1-1", to: "6.9.2.arch1-1", kind: "update" }, { atom: "foo", from: "1.0-1", to: "1.1-1", kind: "update" }]), "updates");
eq(p.parseUpdates("").length, 0, "none");
