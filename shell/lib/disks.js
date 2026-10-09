.pragma library
// Disk Utility's model: lsblk JSON in, disks with partitions out; names,
// sizes, the never-touch rule and mkfs command lines. Pure, so it is tested.

function _bool(v) { return v === true || v === "1" || v === 1; }

function _map(d, kind, parent) {
    return {
        kind: kind, name: d.name, path: d.path || ("/dev/" + d.name), parent: parent,
        label: d.label || d.partlabel || "",
        model: String(d.model || "").trim(), vendor: String(d.vendor || "").trim(), serial: d.serial || "",
        size: parseInt(d.size) || 0, fstype: d.fstype || "",
        fsused: parseInt(d.fsused) || 0, fsavail: parseInt(d.fsavail) || 0, fssize: parseInt(d.fssize) || 0,
        mountpoint: d.mountpoint || "", uuid: d.uuid || "",
        partn: typeof d.partn === "number" ? d.partn : (parseInt(d.partn) || 0),
        // Every mount (btrfs subvolumes mount one partition several times; "mountpoint" names one).
        mountpoints: (d.mountpoints || [d.mountpoint]).filter(function (m) { return !!m; }),
        removable: _bool(d.rm), rota: _bool(d.rota), hotplug: _bool(d.hotplug),
        transport: d.tran || "", state: d.state || "", partTypeName: d.parttypename || "", readOnly: _bool(d.ro)
    };
}

// Volumes mapped inside a partition, at any depth (LUKS → LVM → …).
function _volumes(list, disk, out) {
    for (var i = 0; i < list.length; i++) {
        out.push(_map(list[i], "volume", disk));
        _volumes(list[i].children || [], disk, out);
    }
}

// Whole disks (no loop devices, no zram), each with its partitions and the
// volumes mapped inside them (LUKS, LVM).
function parse(json) {
    var out = [], list = (json && json.blockdevices) || [];
    for (var i = 0; i < list.length; i++) {
        var d = list[i];
        if (d.type !== "disk" || String(d.name).indexOf("zram") === 0) continue;
        var disk = _map(d, "disk", null), used = 0;
        disk.partitions = [];
        var kids = d.children || [];
        for (var k = 0; k < kids.length; k++) {
            var part = _map(kids[k], "partition", d.name);
            disk.partitions.push(part);
            used += part.size;
            _volumes(kids[k].children || [], d.name, disk.partitions);
        }
        disk.freeSpace = Math.max(0, disk.size - used);
        out.push(disk);
    }
    return out;
}

function displayName(dev) {
    if (!dev) return "";
    if (dev.label) return dev.label;
    if (dev.kind === "disk") {
        var m = [dev.vendor, dev.model].filter(function (s) { return s; }).join(" ").trim();
        return m || dev.name;
    }
    return dev.name;
}

function humanSize(bytes) {
    if (!bytes || bytes <= 0) return "—";
    var u = ["bytes", "KB", "MB", "GB", "TB", "PB"], i = 0, v = bytes;
    while (v >= 1000 && i < u.length - 1) { v /= 1000; i++; }
    return (v >= 100 ? Math.round(v) : Math.round(v * 100) / 100) + " " + u[i];
}

var SYSTEM = ["/", "/home", "/usr", "/var", "/opt", "/efi"];
var SYSTEM_MOUNTS = "/ /boot /boot/efi /efi /home /usr /var /opt";
function _sys(mp) { return !!mp && (SYSTEM.indexOf(mp) >= 0 || String(mp).indexOf("/boot") === 0); }
function _anySys(dev) {
    var all = (dev.mountpoints || []).concat([dev.mountpoint]);
    for (var i = 0; i < all.length; i++) if (_sys(all[i])) return true;
    return false;
}

// The disk holding the running system (/, /boot, /home, /usr, /var, /opt —
// protectedDisks: names from findmnt/lsblk) and everything on it are
// read-only to Disk Utility.
function isProtected(dev, protectedDisks) {
    if (!dev) return true;
    var name = dev.kind === "disk" ? dev.name : (dev.parent || "");
    if ((protectedDisks || []).indexOf(name) >= 0) return true;
    if (_anySys(dev)) return true;
    var parts = dev.partitions || [];
    for (var i = 0; i < parts.length; i++) if (_anySys(parts[i])) return true;
    return false;
}

// findmnt names a btrfs subvolume as "/dev/x[/@]"; lsblk wants "/dev/x".
function sourceDevice(src) { return String(src).replace(/\[.*\]$/, ""); }

// A label inside double quotes can carry nothing that ends or expands them.
function _sq(s) { return '"' + String(s).replace(/["\\$`]/g, "") + '"'; }
function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

function mkfsCommand(fs, label, path) {
    var l = label || "";
    switch (fs) {
    case "ext4":  return "mkfs.ext4 -F -L " + _sq(l.substring(0, 16)) + " " + shq(path);
    case "btrfs": return "mkfs.btrfs -f -L " + _sq(l.substring(0, 255)) + " " + shq(path);
    case "xfs":   return "mkfs.xfs -f -L " + _sq(l.substring(0, 12)) + " " + shq(path);
    case "f2fs":  return "mkfs.f2fs -f -l " + _sq(l.substring(0, 255)) + " " + shq(path);
    case "exfat": return "mkfs.exfat -n " + _sq(l.substring(0, 15)) + " " + shq(path);
    case "fat32": return "mkfs.vfat -F 32 -n " + _sq(l.toUpperCase().substring(0, 11)) + " " + shq(path);
    case "ntfs":  return "mkfs.ntfs -f -L " + _sq(l.substring(0, 32)) + " " + shq(path);
    }
    return "";
}

// Fill in formats lsblk did not know, from `findmnt -J -o SOURCE,FSTYPE`.
function fillFormats(devices, findmntJson) {
    var by = {}, list = (findmntJson && findmntJson.filesystems) || [];
    for (var i = 0; i < list.length; i++) by[sourceDevice(list[i].source)] = list[i].fstype;
    for (var k = 0; k < devices.length; k++) {
        var all = [devices[k]].concat(devices[k].partitions || []);
        for (var j = 0; j < all.length; j++) if (!all[j].fstype && by[all[j].path]) all[j].fstype = by[all[j].path];
    }
    return devices;
}

// ---------------------------------------------------------- root scripts --
// What runs under pkexec. Each starts with guardScript: inside the root shell,
// right before acting, the target's top-level disk (lsblk -s walks up through
// LUKS, LVM, RAID) must not hold any system mount. Exit 3 if it does — no UI
// path, stale selection or IPC call gets past this.

function partPath(diskPath, n) {
    return /(nvme|mmcblk|loop)\S*\d$/.test(diskPath) ? diskPath + "p" + n : diskPath + n;
}

function guardScript(devPath) {
    return "D=$(lsblk -nrso NAME,TYPE " + shq(devPath) + " | awk '$2==\"disk\"{print $1}' | tail -n 1); " +
        "[ -n \"$D\" ] || { echo 'unknown device' >&2; exit 3; }; " +
        "for m in " + SYSTEM_MOUNTS + "; do s=$(findmnt -n -o SOURCE --target \"$m\" 2>/dev/null); s=${s%%[*}; " +
        "[ -n \"$s\" ] && lsblk -nrso NAME,TYPE \"$s\" | awk '$2==\"disk\"{print $1}'; done | grep -qx \"$D\" && " +
        "{ echo 'refusing: this disk holds the running system' >&2; exit 3; }; ";
}

function eraseScript(dev, fs, label) {
    if (!dev || !dev.path) return "";
    if (dev.kind === "disk") {
        var part = partPath(dev.path, 1), mk = mkfsCommand(fs, label, part);
        if (!mk) return "";
        return guardScript(dev.path) + "wipefs -a " + shq(dev.path) + " && parted -s " + shq(dev.path) +
            " mklabel gpt mkpart primary 1MiB 100% && udevadm settle && " + mk;
    }
    var m = mkfsCommand(fs, label, dev.path);
    if (!m) return "";
    return guardScript(dev.path) + "wipefs -a " + shq(dev.path) + " && " + m;
}

function tableScript(dev, scheme) {
    if (!dev || dev.kind !== "disk") return "";
    var table = scheme === "msdos" || scheme === "mbr" ? "msdos" : "gpt";
    return guardScript(dev.path) + "wipefs -a " + shq(dev.path) + " && parted -s " + shq(dev.path) + " mklabel " + table;
}

function deleteScript(dev) {
    if (!dev || dev.kind !== "partition" || !dev.partn || !dev.parent) return "";
    var disk = "/dev/" + dev.parent;
    return guardScript(dev.path) + "parted -s " + shq(disk) + " rm " + dev.partn;
}

// The privileged first aid (repair). Look-only checks need no root.
function repairScript(dev) {
    if (!dev || !dev.path) return "";
    return guardScript(dev.path) + "fsck -f -y " + shq(dev.path) + " 2>&1 | tail -n 20";
}

function renameScript(dev, label) {
    if (!dev || !dev.path) return "";
    var l = String(label).replace(/[^A-Za-z0-9 _-]/g, "").substring(0, 32), p = shq(dev.path), c = "";
    switch (dev.fstype) {
    case "ext2": case "ext3": case "ext4": c = "e2label " + p + " " + _sq(l.substring(0, 16)); break;
    case "btrfs": c = "btrfs filesystem label " + p + " " + _sq(l); break;
    case "xfs":   c = "xfs_admin -L " + _sq(l.substring(0, 12)) + " " + p; break;
    case "vfat":  c = "fatlabel " + p + " " + _sq(l.toUpperCase().substring(0, 11)); break;
    case "exfat": c = "exfatlabel " + p + " " + _sq(l.substring(0, 15)); break;
    case "ntfs":  c = "ntfslabel " + p + " " + _sq(l); break;
    default: return "";
    }
    return guardScript(dev.path) + c;
}
