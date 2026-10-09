import { load, eq } from "./lib.mjs";
const d = load("disks.js");
const j = JSON.stringify;

const lsblk = { blockdevices: [
  { name: "loop0", type: "loop", size: 100 },
  { name: "zram0", type: "disk", size: 100 },
  { name: "nvme0n1", type: "disk", size: "1000204886016", model: "Samsung SSD 980 ", vendor: null, tran: "nvme", rm: false, children: [
      { name: "nvme0n1p1", type: "part", size: "536870912", fstype: "vfat", mountpoint: "/boot", label: "EFI" },
      { name: "nvme0n1p2", type: "part", size: "999000000000", fstype: "crypto_LUKS", children: [
          { name: "root", type: "crypt", size: "998000000000", fstype: "ext4", mountpoint: "/" } ] } ] },
  { name: "sda", type: "disk", size: "64000000000", model: "Flash", vendor: "Kingston", tran: "usb", rm: "1", hotplug: true, children: [
      { name: "sda1", type: "part", size: "63000000000", fstype: "exfat", label: "STICK", mountpoint: null } ] }
] };
const devs = d.parse(lsblk);
eq(j(devs.map(x => x.name)), j(["nvme0n1", "sda"]), "disks only; loop and zram skipped");
eq(devs[0].partitions.length, 3, "partitions and the volume inside LUKS");
eq(devs[0].partitions[2].kind, "volume", "mapped volume");
eq(devs[1].removable, true, "rm \"1\" → removable");
eq(devs[1].freeSpace, 1000000000, "free space after partitions");

eq(d.displayName(devs[1]), "Kingston Flash", "vendor + model for a disk");
eq(d.displayName(devs[1].partitions[0]), "STICK", "label for a partition");
eq(d.displayName(devs[0]), "Samsung SSD 980", "trimmed model");

eq(d.humanSize(0), "—", "zero");
eq(d.humanSize(1000204886016), "1 TB", "TB");
eq(d.humanSize(536870912), "537 MB", "MB");
eq(d.humanSize(64000000000), "64 GB", "GB");

// Never the disk under / or /boot: by the list from findmnt, or by its own mount points.
eq(d.isProtected(devs[0], []), true, "root disk by its mount points");
eq(d.isProtected(devs[0].partitions[1], ["nvme0n1"]), true, "its partitions via the list");
eq(d.isProtected(devs[1], []), false, "a USB stick is not");
eq(d.isProtected(devs[1].partitions[0], []), false, "nor its partition");
eq(d.isProtected(null, []), true, "nothing selected → protected");

eq(d.mkfsCommand("ext4", "Data", "/dev/sdb1"), "mkfs.ext4 -F -L \"Data\" '/dev/sdb1'", "ext4");
eq(d.mkfsCommand("fat32", "my stick", "/dev/sdb1"), "mkfs.vfat -F 32 -n \"MY STICK\" '/dev/sdb1'", "fat32 label upper, max 11");
eq(d.mkfsCommand("exfat", 'a"b$c', "/dev/sdb1"), "mkfs.exfat -n \"abc\" '/dev/sdb1'", "label cannot break out of quotes");
eq(d.mkfsCommand("zfs", "x", "/dev/sdb1"), "", "unknown filesystem → nothing");
eq(d.shq("it's"), "'it'\\''s'", "shell quoting");

// btrfs: one partition, several mounts (subvolumes). lsblk's "mountpoint" names
// only one of them; "mountpoints" has all — / among them must protect the disk.
{
  const bt = d.parse({ blockdevices: [
    { name: "nvme2n1", type: "disk", size: "512000000000", children: [
      { name: "nvme2n1p1", type: "part", size: "512000000000", fstype: "btrfs", mountpoint: "/home", mountpoints: ["/home", "/"] } ] },
    { name: "sdc", type: "disk", size: "8000000000", rm: true, children: [
      { name: "sdc1", type: "part", size: "8000000000", fstype: "vfat", mountpoint: null, mountpoints: [null] } ] } ] });
  eq(d.isProtected(bt[0], []), true, "root among a partition's mount points protects the disk");
  eq(d.isProtected(bt[0].partitions[0], []), true, "and the partition itself");
  eq(d.isProtected(bt[1], []), false, "an unmounted stick is not protected");
  eq(JSON.stringify(bt[0].partitions[0].mountpoints), JSON.stringify(["/home", "/"]), "all mount points kept");
}
// /home and the other system mounts count too.
eq(d.isProtected({ kind: "partition", parent: "x", mountpoint: "/home", mountpoints: ["/home"] }, []), true, "/home is part of the running system");
// The device findmnt names for a btrfs subvolume: "/dev/x[/@]" → "/dev/x".
eq(d.sourceDevice("/dev/nvme2n1p1[/@]"), "/dev/nvme2n1p1", "subvolume suffix dropped");
eq(d.sourceDevice("/dev/sda1"), "/dev/sda1", "plain device unchanged");

// lsblk may not know a format (no udev data for this user); a mounted volume's
// comes from findmnt.
{
  const ds = d.parse({ blockdevices: [{ name: "nvme2n1", type: "disk", size: "1", children: [
    { name: "nvme2n1p1", type: "part", size: "1", fstype: null, mountpoints: ["/home", "/"] },
    { name: "nvme2n1p2", type: "part", size: "1", fstype: "swap" } ] }] });
  d.fillFormats(ds, { filesystems: [{ source: "/dev/nvme2n1p1[/@]", fstype: "btrfs" }, { source: "/dev/nvme2n1p1[/@home]", fstype: "btrfs" }] });
  eq(ds[0].partitions[0].fstype, "btrfs", "format from findmnt, subvolume suffix ignored");
  eq(ds[0].partitions[1].fstype, "swap", "a known format stays");
}

// ---- privileged commands: built here, guarded inside the root shell ----
eq(d.partPath("/dev/sdb", 1), "/dev/sdb1", "sd partition path");
eq(d.partPath("/dev/nvme1n1", 2), "/dev/nvme1n1p2", "nvme partition path");
eq(d.partPath("/dev/mmcblk0", 1), "/dev/mmcblk0p1", "mmc partition path");

// The partition number comes from lsblk's partn, never from the name.
{
  const ds = d.parse({ blockdevices: [{ name: "nvme1n1", type: "disk", size: "1", children: [
    { name: "nvme1n1p2", type: "part", size: "1", partn: 2 } ] }] });
  eq(ds[0].partitions[0].partn, 2, "partn kept");
  eq(d.deleteScript(ds[0].partitions[0]).indexOf("rm 2") > 0, true, "deletes partition 2 of nvme1n1");
  eq(d.deleteScript({ kind: "partition", parent: "x", path: "/dev/x9" }), "", "no partn → nothing");
  eq(d.deleteScript({ kind: "volume", parent: "x", path: "/dev/dm-0", partn: 1 }), "", "only partitions");
}
// LUKS+LVM: volumes inside volumes are kept, so their mounts protect the disk.
{
  const ds = d.parse({ blockdevices: [{ name: "sda", type: "disk", size: "1", children: [
    { name: "sda2", type: "part", size: "1", fstype: "crypto_LUKS", children: [
      { name: "luks", type: "crypt", size: "1", fstype: "LVM2_member", children: [
        { name: "vg-root", type: "lvm", size: "1", fstype: "ext4", mountpoints: ["/"] } ] } ] } ] }] });
  eq(ds[0].partitions.map(p => p.name).join(","), "sda2,luks,vg-root", "every level");
  eq(d.isProtected(ds[0], []), true, "disk with an LVM root inside LUKS is protected");
  eq(d.isProtected(ds[0].partitions[0], ["sda"]), true, "its partition via the disk list");
}
eq(d.isProtected({ kind: "partition", parent: "sda", mountpoints: ["/efi"] }, []), true, "/efi is system");

// Every privileged script starts with the guard and names the device quoted.
for (const s of [d.eraseScript({ kind: "partition", path: "/dev/sdb1" }, "ext4", "Data"),
                 d.eraseScript({ kind: "disk", path: "/dev/sdb" }, "exfat", "Stick"),
                 d.tableScript({ kind: "disk", path: "/dev/sdb" }, "msdos"),
                 d.deleteScript({ kind: "partition", parent: "sdb", path: "/dev/sdb1", partn: 1 })]) {
  eq(s.indexOf(d.guardScript("/dev/sdb")) === 0 || s.indexOf("lsblk -nrso NAME,TYPE '/dev/sdb") > 0, true, "guarded: " + s.slice(0, 40));
  eq(s.indexOf("exit 3") > 0, true, "refuses with exit 3");
}
eq(d.tableScript({ kind: "disk", path: "/dev/sdb" }, "msdos").indexOf("mklabel msdos") > 0, true, "MBR is msdos");
eq(d.tableScript({ kind: "disk", path: "/dev/sdb" }, "gpt").indexOf("mklabel gpt") > 0, true, "GPT");
const whole = d.eraseScript({ kind: "disk", path: "/dev/nvme2n1" }, "ext4", "Big");
eq(whole.indexOf("mklabel gpt") > 0 && whole.indexOf("mkfs.ext4 -F -L \"Big\" '/dev/nvme2n1p1'") > 0, true, "a whole drive gets a table and one partition");
eq(d.eraseScript({ kind: "disk", path: "/dev/sdb" }, "zfs", "x"), "", "unknown format → nothing");

// Rename: guarded, label limited to safe characters, the device quoted.
{
  const r = d.renameScript({ kind: "partition", path: "/dev/sdb1", fstype: "ext4" }, "My Data;rm -rf /");
  eq(r.indexOf("e2label '/dev/sdb1' \"My Datarm -rf \"") > 0, true, "label cleaned: " + r.slice(-40));
  eq(r.indexOf("exit 3") > 0, true, "guarded");
  eq(d.renameScript({ kind: "partition", path: "/dev/sdb1", fstype: "crypto_LUKS" }, "x"), "", "no label tool → nothing");
  eq(d.renameScript({ kind: "partition", path: "/dev/sdb1", fstype: "vfat" }, "stick").indexOf('fatlabel \'/dev/sdb1\' "STICK"') > 0, true, "vfat upper");
}
