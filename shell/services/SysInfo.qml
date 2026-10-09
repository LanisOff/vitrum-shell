pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Everything About and the Settings overview need to say about this
 * machine, plus the live CPU/memory figures the Control Centre shows.
 *
 * Static facts are read once. Live figures poll, but only while something is
 * actually looking at them — `subscribers` is incremented by the surfaces that
 * display them, so a closed Control Centre costs nothing.
 */
Singleton {
    id: root

    // -------------------------------------------------------- static ------

    property string hostname: ""
    property string userName: ""
    property string userRealName: ""
    property string kernel: ""
    property string distro: ""
    property string arch: ""
    property string cpuModel: ""
    property int cpuCores: 0
    property int cpuThreads: 0
    property string gpuModel: ""
    property real memoryTotalGB: 0
    property string memoryDetail: ""
    property string boardModel: ""
    property string boardVendor: ""
    property string biosVersion: ""
    property string serial: ""
    property string uptime: ""
    property string niriVersion: ""
    property int packageCount: 0
    property string primaryDisplay: ""

    /// The line About puts under the big model name.
    readonly property string modelLine: {
        if (boardVendor && boardModel) return boardVendor + " " + boardModel;
        return boardModel || boardVendor || "Linux PC";
    }

    Component.onCompleted: staticInfo.running = true

    Process {
        id: staticInfo
        command: ["sh", "-c", `
            printf 'hostname=%s\\n' "$(hostnamectl hostname 2>/dev/null || uname -n)"
            printf 'user=%s\\n' "$USER"
            printf 'realname=%s\\n' "$(getent passwd "$USER" | cut -d: -f5 | cut -d, -f1)"
            printf 'kernel=%s\\n' "$(uname -r)"
            printf 'arch=%s\\n' "$(uname -m)"
            printf 'distro=%s\\n' "$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")"
            printf 'cpu=%s\\n' "$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')"
            printf 'cores=%s\\n' "$(grep -m1 'cpu cores' /proc/cpuinfo | cut -d: -f2 | tr -d ' ')"
            printf 'threads=%s\\n' "$(nproc)"
            printf 'gpu=%s\\n' "$(lspci 2>/dev/null | grep -iE 'vga|3d controller' | head -n1 | sed 's/.*: //')"
            printf 'memkb=%s\\n' "$(grep MemTotal /proc/meminfo | awk '{print $2}')"
            printf 'memdetail=%s\\n' "$(sudo -n dmidecode -t memory 2>/dev/null | grep -m1 -E 'Speed: [0-9]' | sed 's/.*Speed: //')"
            printf 'board=%s\\n' "$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null)"
            printf 'vendor=%s\\n' "$(cat /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null)"
            printf 'bios=%s\\n' "$(cat /sys/devices/virtual/dmi/id/bios_version 2>/dev/null)"
            printf 'serial=%s\\n' "$(cat /sys/devices/virtual/dmi/id/product_serial 2>/dev/null || echo unavailable)"
            printf 'niri=%s\\n' "$(niri --version 2>/dev/null | head -n1 | sed 's/^niri //')"
            if [ -d /var/db/pkg ]; then printf 'packages=%s\\n' "$(ls -d /var/db/pkg/*/*/ 2>/dev/null | wc -l)"
            else printf 'packages=%s\\n' "$(pacman -Qq 2>/dev/null | wc -l)"; fi
            printf 'uptime=%s\\n' "$(cut -d. -f1 /proc/uptime)"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const kv = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=");
                    if (i > 0) kv[line.substring(0, i)] = line.substring(i + 1).trim();
                }
                root.hostname = kv.hostname || "";
                root.userName = kv.user || "";
                root.userRealName = kv.realname || kv.user || "";
                root.kernel = kv.kernel || "";
                root.arch = kv.arch || "";
                root.distro = kv.distro || "";
                root.cpuModel = kv.cpu || "";
                root.cpuCores = parseInt(kv.cores) || 0;
                root.cpuThreads = parseInt(kv.threads) || 0;
                root.gpuModel = kv.gpu || "";
                root.memoryTotalGB = Math.round(((parseInt(kv.memkb) || 0) / 1048576) * 10) / 10;
                root.memoryDetail = kv.memdetail || "";
                root.boardModel = kv.board || "";
                root.boardVendor = kv.vendor || "";
                root.biosVersion = kv.bios || "";
                root.serial = kv.serial || "";
                root.niriVersion = kv.niri || "";
                root.packageCount = parseInt(kv.packages) || 0;
                const up = parseInt(kv.uptime) || 0;
                if (up && !root.uptime) root.uptime = up >= 86400 ? Math.floor(up / 86400) + " d " + Math.floor(up % 86400 / 3600) + " h"
                                                                    : Math.floor(up / 3600) + " h " + Math.floor(up % 3600 / 60) + " min";
            }
        }
    }

    // ---------------------------------------------------------- live ------

    property int subscribers: 0
    property real cpuUsage: 0
    property real memoryUsedGB: 0
    property real memoryUsage: 0
    property real swapUsage: 0
    property real cpuTemp: 0

    function subscribe()   { subscribers++; }
    function unsubscribe() { subscribers = Math.max(0, subscribers - 1); }

    property var _lastCpu: null

    Timer {
        interval: 2000
        running: root.subscribers > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: live.running = true
    }

    Process {
        id: live
        command: ["sh", "-c",
            "head -n1 /proc/stat; " +
            "grep -E 'MemTotal|MemAvailable|SwapTotal|SwapFree' /proc/meminfo; " +
            // The CPU sensor: a thermal zone where there is one (laptops), else
            // hwmon — desktop AMD has no zones, only k10temp / zenpower.
            "{ cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null || for h in /sys/class/hwmon/hwmon*; do " +
            "case $(cat $h/name 2>/dev/null) in k10temp|zenpower|coretemp|cpu_thermal) cat $h/temp1_input; break;; esac; done; } | head -n1; " +
            "uptime -p 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root._parseLive(text)
        }
    }

    function _parseLive(txt) {
        const lines = txt.split("\n");
        const mem = {};
        for (const line of lines) {
            if (line.indexOf("cpu ") === 0) {
                const f = line.trim().split(/\s+/).slice(1).map(Number);
                const idle = f[3] + (f[4] || 0);
                const total = f.reduce((a, b) => a + b, 0);
                if (_lastCpu) {
                    const dt = total - _lastCpu.total;
                    const di = idle - _lastCpu.idle;
                    if (dt > 0) cpuUsage = Math.max(0, Math.min(1, 1 - di / dt));
                }
                _lastCpu = { total: total, idle: idle };
            } else if (line.indexOf("Mem") === 0 || line.indexOf("Swap") === 0) {
                const p = line.split(":");
                mem[p[0]] = parseInt(p[1]) || 0;
            } else if (/^\d+$/.test(line.trim()) && line.trim().length >= 4) {
                cpuTemp = parseInt(line.trim()) / 1000;
            } else if (line.indexOf("up ") === 0) {
                uptime = line.trim().replace(/^up /, "");
            }
        }
        if (mem.MemTotal) {
            const used = mem.MemTotal - (mem.MemAvailable || 0);
            memoryUsedGB = Math.round((used / 1048576) * 10) / 10;
            memoryUsage = used / mem.MemTotal;
        }
        if (mem.SwapTotal > 0) {
            swapUsage = (mem.SwapTotal - (mem.SwapFree || 0)) / mem.SwapTotal;
        }
    }

    // -------------------------------------------------------- displays ----

    property var displays: []

    function refreshDisplays() { displayProc.running = true; }

    Process {
        id: displayProc
        command: ["sh", "-c", "niri msg --json outputs 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const obj = JSON.parse(text);
                    const list = [];
                    for (const key in obj) {
                        const o = obj[key];
                        const modes = o.modes || [];
                        const cur = o.current_mode !== null && o.current_mode !== undefined
                                  ? modes[o.current_mode] : null;
                        list.push({
                            name: key,
                            make: o.make || "",
                            model: o.model || "",
                            serial: o.serial || "",
                            width: cur ? cur.width : 0,
                            height: cur ? cur.height : 0,
                            refresh: cur ? Math.round(cur.refresh_rate / 1000) : 0,
                            scale: o.logical ? o.logical.scale : 1,
                            transform: o.logical ? o.logical.transform : "normal",
                            vrr: !!o.vrr_enabled,
                            modes: modes.map(m => ({
                                width: m.width, height: m.height,
                                refresh: Math.round(m.refresh_rate / 1000),
                                preferred: !!m.is_preferred
                            }))
                        });
                    }
                    root.displays = list;
                    if (list.length > 0)
                        root.primaryDisplay = list[0].width + " × " + list[0].height;
                } catch (e) { root.displays = []; }
            }
        }
    }

    Component.onDestruction: {}
    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: root.refreshDisplays() }

    // ------------------------------------------------------------- GPU ----
    //
    // NVIDIA through nvidia-smi when it is there; other GPUs report through
    // hwmon as part of the temperature sensors and have no usage figure here.

    property bool gpuAvailable: false
    property real gpuUsage: 0
    property real gpuTemp: 0

    Timer {
        interval: 2000; repeat: true; triggeredOnStart: true
        running: root.subscribers > 0
        onTriggered: gpuProc.running = true
    }
    Process {
        id: gpuProc
        command: ["sh", "-c", "command -v nvidia-smi >/dev/null && nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(",").map(s => parseFloat(s));
                root.gpuAvailable = p.length === 2 && !isNaN(p[0]);
                if (root.gpuAvailable) { root.gpuUsage = p[0] / 100; root.gpuTemp = p[1]; }
            }
        }
    }
}
