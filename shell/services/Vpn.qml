pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "../lib/vpn.js" as Lib

/*
 * VPN: Throne (its tunnel, from the tray — the mode, the server and the place
 * are in its tooltip, the switch is its "Operation Mode → Tun Mode" menu
 * entry) and WireGuard (wg-quick through the root helper).
 */
Singleton {
    id: root

    // ------------------------------------------------------------ Throne ---
    readonly property var throneItem: {
        for (const i of SystemTray.items.values)
            if (/throne/i.test((i.id || "") + " " + (i.title || "") + " " + (i.tooltipTitle || ""))) return i;
        return null;
    }
    readonly property var throne: Lib.parseThrone(throneItem ? throneItem.tooltipTitle : "")
    property bool tunLink: false      // /sys/class/net/throne-tun
    readonly property bool throneOn: tunLink || throne.tun

    QsMenuOpener { id: top; menu: root.throneItem && root.throneItem.hasMenu ? root.throneItem.menu : null }
    QsMenuOpener {
        id: modes
        menu: {
            for (const e of top.children.values) if (/operation mode|режим/i.test(e.text || "")) return e;
            return null;
        }
    }
    function toggleThrone() {
        for (const e of modes.children.values)
            if (/\btun\b/i.test(e.text || "")) { e.triggered(); recheck.restart(); return true; }
        return false;
    }

    // --------------------------------------------------------- WireGuard ---
    readonly property string helper: "/usr/local/libexec/vitrum/vitrum-root"
    property var wgConfigs: []        // names in /etc/wireguard
    property var wgUp: []             // links up now
    property bool wgAfterList: false
    onWgConfigsChanged: if (wgAfterList && wgConfigs.length) { wgAfterList = false; toggleWg(wgConfigs[0]); }
    function toggleWg(name) {
        Quickshell.execDetached(["pkexec", helper, wgUp.indexOf(name) >= 0 ? "wg-down" : "wg-up", name]);
        recheck.restart();
    }
    // The configs are root's to read, so they are listed (through the helper)
    // only when asked for: opening Control Centre with WireGuard set up.
    property bool wgPresent: false
    function listWg() { if (wgPresent && !wgList.running) wgList.running = true; }
    Process {
        id: wgList
        command: ["sh", "-c", 'test -x "$1" && pkexec "$1" wg-list 2>/dev/null', "_", root.helper]
        stdout: StdioCollector { onStreamFinished: root.wgConfigs = text.split("\n").filter(s => s.trim()) }
    }
    Process {
        running: true
        command: ["sh", "-c", 'command -v wg-quick >/dev/null && test -d /etc/wireguard && test -x "$1"', "_", root.helper]
        onExited: code => root.wgPresent = code === 0
    }

    // ------------------------------------------------------------- state ---
    readonly property bool active: throneOn || wgUp.length > 0
    readonly property string label: throneOn ? (throne.short || throne.server || "Throne") : wgUp.length ? wgUp.join(", ") : ""
    readonly property string detail: throneOn ? [throne.protocol, throne.server].filter(s => s).join(" · ") : wgUp.length ? "WireGuard" : ""
    readonly property bool available: throneItem !== null || wgPresent
    /// The chip's switch: Throne's tunnel when Throne runs, else the first WireGuard config.
    function toggle() {
        if (throneItem) toggleThrone();
        else if (wgUp.length) toggleWg(wgUp[0]);
        else if (wgConfigs.length) toggleWg(wgConfigs[0]);
        else { listWg(); wgAfterList = true; }
    }

    Process {
        id: probe
        command: ["sh", "-c", 'test -e /sys/class/net/throne-tun && echo tun; ip -br link show type wireguard 2>/dev/null']
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.tunLink = lines[0] === "tun";
                root.wgUp = Lib.wgLinks(lines.slice(lines[0] === "tun" ? 1 : 0).join("\n"));
            }
        }
    }
    Timer { interval: 5000; repeat: true; running: true; triggeredOnStart: true; onTriggered: if (!probe.running) probe.running = true }
    Timer { id: recheck; interval: 1500; onTriggered: if (!probe.running) probe.running = true }
}
