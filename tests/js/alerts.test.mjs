import { load, eq } from "./lib.mjs";
const a = load("alerts.js");

// Too hot must last before it is said, and is said once per cooldown.
{
  let s = {};
  let r = a.watch(s, "cpu", true, 0, 30, 600); s = r.state;
  eq(r.fire, false, "not at once");
  r = a.watch(s, "cpu", true, 29, 30, 600); s = r.state;
  eq(r.fire, false, "not before it lasted");
  r = a.watch(s, "cpu", true, 31, 30, 600); s = r.state;
  eq(r.fire, true, "after it lasted");
  r = a.watch(s, "cpu", true, 100, 30, 600); s = r.state;
  eq(r.fire, false, "once");
  r = a.watch(s, "cpu", false, 120, 30, 600); s = r.state;
  r = a.watch(s, "cpu", true, 130, 30, 600); s = r.state;
  r = a.watch(s, "cpu", true, 200, 30, 600); s = r.state;
  eq(r.fire, false, "again within the cooldown: quiet");
  r = a.watch(s, "cpu", true, 700, 30, 600); s = r.state;
  eq(r.fire, true, "after the cooldown");
}
// No hold: at once.
eq(a.watch({}, "disk:/", true, 5, 0, 600).fire, true, "disks: at once");

// df -P -B1 → mounts that are nearly full.
const df = [
  "Filesystem     1-blocks         Used    Available Capacity Mounted on",
  "/dev/nvme0n1p2 500000000000 460000000000 40000000000      92% /",
  "/dev/sda1      2000000000000 100000000000 1900000000000     5% /mnt/data",
  "/dev/nvme0n1p1 1073741824 1000000000 73741824     94% /boot",
].join("\n");
{
  const full = a.fullDisks(df, 90, 10 * 1024 ** 3);
  eq(full.map(f => f.mount).join(","), "/,/boot", "over 90%");
  eq(full[0].freeGB, 37.3, "free in GB");
  eq(a.fullDisks(df, 99, 50 * 1024 ** 3).map(f => f.mount).join(","), "/", "or under the free floor — not a small /boot");
  // A small partition (a 1 GB /boot at 36%) is not "nearly full" for having under 10 GB.
  const small = "Filesystem 1-blocks Used Available Capacity Mounted on\n/dev/nvme0n1p1 1073741824 386547056 687194768 36% /boot";
  eq(a.fullDisks(small, 90, 10 * 1024 ** 3).length, 0, "small partitions by percent only");
}

// smartctl -j → healthy or what is wrong.
eq(a.smartProblem({ smart_status: { passed: true } }), "", "fine");
eq(a.smartProblem({ smart_status: { passed: false } }), "the drive reports it is failing", "failing");
eq(a.smartProblem({ smart_status: { passed: true }, nvme_smart_health_information_log: { critical_warning: 4, media_errors: 0 } }), "critical warning 4", "nvme warning");
eq(a.smartProblem({ smart_status: { passed: true }, nvme_smart_health_information_log: { critical_warning: 0, media_errors: 3 } }), "3 media errors", "media errors");
eq(a.smartProblem({ smart_status: { passed: true }, ata_smart_attributes: { table: [{ id: 5, name: "Reallocated_Sector_Ct", raw: { value: 12 } }] } }), "12 reallocated sectors", "reallocated");
eq(a.smartProblem(null), "", "no answer is not a problem");
