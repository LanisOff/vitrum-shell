import { load, eq, ok } from "./lib.mjs";
const p = load("procs.js");
const j = JSON.stringify;

// A stat line: pid (comm) state, then fields 4..; utime is field 14, stime 15, rss 24.
function stat(pid, comm, utime, stime, rss) {
  const f = ["S"]; for (let i = 4; i <= 52; i++) f.push("0");
  f[11] = String(utime); f[12] = String(stime); f[21] = String(rss);
  return `${pid} (${comm}) ${f.join(" ")}`;
}
const a = p.parseSample(["page 4096", "MemTotal:       16000000 kB", "cpu  100 0 100 800 0 0 0 0 0 0",
  stat(1, "systemd", 5, 5, 1000), stat(42, "Web Content", 10, 0, 50000), stat(43, "Web Content", 0, 0, 25000),
  stat(77, "weird) (name", 1, 1, 10), "garbage", ""].join("\n"));
eq(a.total, 1000, "total ticks: the first eight fields");
eq(a.page, 4096, "page size");
eq(a.memTotal, 16000000 * 1024, "MemTotal in bytes");
eq(a.procs["42"].name, "Web Content", "a name with a space");
eq(a.procs["42"].ticks, 10, "utime + stime");
eq(a.procs["77"].name, "weird) (name", "a name with brackets ends at the last ') '");
eq(Object.keys(a.procs).length, 4, "junk lines skipped");
{
  const k = stat(5, "kworker/0:1-events", 50, 50, 0).split(" "); k[8] = String(0x00208040);   // field 9: flags with PF_KTHREAD
  eq(Object.keys(p.parseSample(k.join(" ")).procs).length, 0, "kernel threads left out");
}

// No reading before: no processor shares, memory still ranks.
eq(p.top(null, a, "cpu", 5, false).every(r => r.cpu === 0), true, "first reading: cpu 0");
eq(p.top(null, a, "memory", 1, false)[0].bytes, 50000 * 4096, "memory without a reading before");

const b = p.parseSample(["page 4096", "MemTotal:       16000000 kB", "cpu  300 0 300 1400 0 0 0 0 0 0",
  stat(1, "systemd", 6, 5, 1000), stat(42, "Web Content", 210, 0, 50000), stat(43, "Web Content", 100, 0, 25000),
  stat(99, "new", 50, 0, 100), stat(77, "reused", 30, 0, 10)].join("\n"));
// dt = 2000 - 1000 = 1000 ticks.
const t = p.top(a, b, "cpu", 10, false);
eq(t[0].name, "Web Content", "busiest first");
eq(t[0].cpu, 0.2, "share of the machine's ticks");
eq(t.find(r => r.name === "new").cpu, 0.05, "a new process: all its ticks");
eq(t.find(r => r.name === "reused").cpu, 0.03, "a reused pid starts from nothing");
eq(t.find(r => r.name === "systemd").cpu, 0.001, "a quiet one");
const g = p.top(a, b, "cpu", 2, true);
eq(g.length, 2, "n kept");
eq(g[0].name, "Web Content", "grouped by name");
eq(g[0].count, 2, "two processes in the group");
eq(Math.round(g[0].cpu * 1000), 300, "the group adds up");
eq(g[0].bytes, 75000 * 4096, "the group's memory adds up");
const m = p.top(a, b, "memory", 1, true);
eq(m[0].name, "Web Content", "by memory");
ok(Math.abs(m[0].mem - 75000 * 4096 / (16000000 * 1024)) < 1e-9, "memory share");
eq(j(p.top(a, null, "cpu", 5, true)), "[]", "no reading: nothing");

eq(p.percent(0.2), "20%", "whole above 10");
eq(p.percent(0.0042), "0.4%", "one decimal under 10");
eq(p.percent(0), "0.0%", "none");
eq(p.size(512 * 1048576), "512 MB", "MB");
eq(p.size(3.25 * 1073741824), "3.3 GB", "GB");
