pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/disks.js" as Lib

/*
 * The storage model behind Disk Utility.
 *
 * Reads come from `lsblk -J -O`, which reports everything in one JSON call.
 * Non-destructive actions go through udisksctl, which the installer's polkit
 * rule lets an active local session perform without a prompt. Destructive ones
 * go through pkexec and always authenticate.
 *
 * Two safety rules are enforced here rather than in the UI, so no future
 * button can bypass them:
 *
 *   1. A device that is, or contains, the mount point of / or /boot is
 *      permanently read-only to this application.
 *   2. Every destructive call is a single function that takes an explicit
 *      confirmation token; there is no way to reach mkfs without one.
 */
Singleton {
    id: root

    property var devices: []          // whole disks, each with .partitions
    property bool loading: false
    property string lastError: ""
    property string busyMessage: ""

    signal operationFinished(bool ok, string message)

    // The disks we must never touch. Computed once from findmnt, because the
    // answer cannot change while the session is running.
    property var protectedDisks: []

    Component.onCompleted: {
        protectProc.running = true;
        refresh();
    }

    // The top-level disks under every system mount: lsblk -s walks up through
    // LUKS, LVM and RAID (PKNAME stops one level up); ${s%%[*} drops a btrfs
    // subvolume suffix. The root scripts check the same again before acting.
    Process {
        id: protectProc
        command: ["sh", "-c",
            "for m in / /boot /boot/efi /efi /home /usr /var /opt; do " +
            "  s=$(findmnt -n -o SOURCE --target \"$m\" 2>/dev/null); s=${s%%[*}; " +
            "  [ -n \"$s\" ] && lsblk -nrso NAME,TYPE \"$s\" 2>/dev/null | awk '$2==\"disk\"{print $1}'; " +
            "done | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.protectedDisks = text.trim().split("\n").filter(s => s.length > 0);
            }
        }
    }

    function isProtected(dev) { return Lib.isProtected(dev, protectedDisks); }

    // -------------------------------------------------------------- read ---

    function refresh() {
        loading = true;
        lsblk.running = true;
    }

    Process {
        id: lsblk
        command: ["lsblk", "-J", "-O", "-b"]
        stdout: StdioCollector {
            onStreamFinished: root._parse(text)
        }
        onExited: code => {
            root.loading = false;
            if (code !== 0) root.lastError = "lsblk failed";
        }
    }

    function _parse(txt) {
        try { _pending = Lib.parse(JSON.parse(txt)); }
        catch (e) { lastError = "could not read the device list"; loading = false; return; }
        mounts.running = true;            // formats lsblk did not know come from findmnt
    }
    property var _pending: []
    Process {
        id: mounts
        command: ["findmnt", "-J", "-o", "SOURCE,FSTYPE"]
        stdout: StdioCollector {
            onStreamFinished: {
                let j = {};
                try { j = JSON.parse(text); } catch (e) {}
                root.devices = Lib.fillFormats(root._pending, j);
                root.loading = false;
            }
        }
    }

    function displayName(dev) { return Lib.displayName(dev); }
    function humanSize(bytes) { return Lib.humanSize(bytes); }

    // ------------------------------------------------- safe operations -----

    function mount(dev) {
        _run(["udisksctl", "mount", "-b", dev.path], "Mounting " + displayName(dev));
    }

    function unmount(dev) {
        _run(["udisksctl", "unmount", "-b", dev.path], "Unmounting " + displayName(dev));
    }

    function eject(dev) {
        // Unmount every partition first, then power the drive down. Ejecting a
        // still-mounted disk is how people lose data.
        const parts = (dev.partitions || []).filter(p => p.mountpoint);
        const cmds = parts.map(p => "udisksctl unmount -b " + _q(p.path)).join("; ");
        _runShell((cmds ? cmds + "; " : "") + "udisksctl power-off -b " + _q(dev.path),
                  "Ejecting " + displayName(dev));
    }

    /// First Aid: check and repair, read-only for a mounted filesystem.
    function firstAid(dev) {
        // Mounted anywhere (all mount points: btrfs) or part of the running system: look, never repair.
        if (dev.mountpoint || (dev.mountpoints && dev.mountpoints.length) || isProtected(dev)) {
            _runShell("fsck -n " + _q(dev.path) + " 2>&1 | tail -n 20",
                      "Checking " + displayName(dev) + " (read-only; unmount to repair)");
            return;
        }
        _runShell("pkexec sh -c " + _q(Lib.repairScript(dev)), "Repairing " + displayName(dev));
    }

    // --------------------------------------------- destructive operations ---
    //
    // Every one of these takes `confirmationToken`, which the UI sets to the
    // exact name of the volume the user typed. If it does not match, nothing
    // runs. This is the only path to mkfs in the application.

    function erase(dev, newLabel, fsType, confirmationToken) {
        if (isProtected(dev)) {
            operationFinished(false, "That device holds your running system and cannot be erased.");
            return;
        }
        if (confirmationToken !== displayName(dev)) {
            operationFinished(false, "The confirmation did not match. Nothing was changed.");
            return;
        }

        const script = Lib.eraseScript(dev, fsType, newLabel);
        if (!script) {
            operationFinished(false, "Unsupported filesystem: " + fsType);
            return;
        }
        // Everything on it unmounted first (a drive's partitions too), then the guarded root script.
        _runShell(
            "for p in $(lsblk -nlo PATH " + _q(dev.path) + "); do udisksctl unmount -b \"$p\" 2>/dev/null || true; done; " +
            "pkexec sh -c " + _q(script) + " && udevadm settle",
            "Erasing " + displayName(dev));
    }

    function _mkfsCommand(fs, label, path) { return Lib.mkfsCommand(fs, label, path); }

    /// Wipe a whole disk and lay down a fresh partition table.
    function repartition(dev, scheme, confirmationToken) {
        if (dev.kind !== "disk") {
            operationFinished(false, "Only a whole disk can be repartitioned.");
            return;
        }
        if (isProtected(dev)) {
            operationFinished(false, "That disk holds your running system and cannot be repartitioned.");
            return;
        }
        if (confirmationToken !== displayName(dev)) {
            operationFinished(false, "The confirmation did not match. Nothing was changed.");
            return;
        }
        _runShell(
            "for p in $(lsblk -nlo PATH " + _q(dev.path) + " | tail -n +2); do " +
            "  udisksctl unmount -b \"$p\" 2>/dev/null || true; done; " +
            "pkexec sh -c " + _q(Lib.tableScript(dev, scheme)) + " && udevadm settle",
            "Repartitioning " + displayName(dev));
    }

    function deletePartition(dev, confirmationToken) {
        if (isProtected(dev)) {
            operationFinished(false, "That partition is part of your running system.");
            return;
        }
        if (confirmationToken !== displayName(dev)) {
            operationFinished(false, "The confirmation did not match. Nothing was changed.");
            return;
        }
        const script = Lib.deleteScript(dev);
        if (!script) {
            operationFinished(false, "Only a partition with a known number can be deleted.");
            return;
        }
        _runShell(
            "udisksctl unmount -b " + _q(dev.path) + " 2>/dev/null || true; " +
            "pkexec sh -c " + _q(script) + " && udevadm settle",
            "Deleting " + displayName(dev));
    }

    function rename(dev, newLabel) {
        if (isProtected(dev)) {
            operationFinished(false, "This volume belongs to the running system. Nothing was changed.");
            return;
        }
        const script = Lib.renameScript(dev, newLabel);
        if (!script) {
            operationFinished(false, "This volume has no filesystem that can be renamed here.");
            return;
        }
        _runShell("pkexec sh -c " + _q(script), "Renaming " + displayName(dev));
    }

    // ------------------------------------------------------------- runner ---

    property string output: ""

    function _run(cmdline, message) {
        busyMessage = message;
        output = "";
        op.command = cmdline;
        op.running = true;
    }

    function _runShell(script, message) {
        busyMessage = message;
        output = "";
        op.command = ["sh", "-c", script];
        op.running = true;
    }

    Process {
        id: op
        stdout: StdioCollector {
            onStreamFinished: root.output += text
        }
        stderr: StdioCollector {
            onStreamFinished: root.output += text
        }
        onExited: code => {
            const msg = root.busyMessage;
            root.busyMessage = "";
            if (code === 0) {
                root.operationFinished(true, msg + " — done");
            } else if (code === 126 || code === 127) {
                root.operationFinished(false, "Authentication was cancelled or the tool is missing.");
            } else {
                root.operationFinished(false, msg + " failed:\n" + root.output.trim());
            }
            root.refresh();
        }
    }

    // Escaping for the outer `sh -c` layer, and for a value inside it.
    function _q(s)  { return Lib.shq(s); }
}
