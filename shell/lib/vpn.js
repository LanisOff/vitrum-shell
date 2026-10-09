.pragma library
// VPN state for the bar: Throne (from its tray tooltip) and WireGuard links.

// Throne's tooltip: "[Tun+System Proxy]\nThrone\n[Shadowsocks] LV / Shadowsocks@xeovo\n🇱🇻 Latvia, Riga"
function parseThrone(tip) {
    var lines = String(tip || "").split("\n").map(function (s) { return s.trim(); }).filter(function (s) { return s; });
    var out = { tun: false, proxy: false, protocol: "", server: "", place: "", short: "" };
    var i = 0;
    var modes = /^\[([^\]]*)\]$/.exec(lines[0] || "");
    if (modes) {
        var m = modes[1].toLowerCase();
        out.tun = /\btun\b/.test(m);
        out.proxy = /proxy/.test(m);
        i = 1;
    }
    for (; i < lines.length; i++) {
        var s = /^\[([^\]]+)\]\s*(.+)$/.exec(lines[i]);
        if (s && !out.server) { out.protocol = s[1]; out.server = s[2]; continue; }
        if (out.server && !out.place) { out.place = lines[i]; }
    }
    out.short = out.place.replace(/^[\uD83C][\uDDE6-\uDDFF][\uD83C][\uDDE6-\uDDFF]\s*/, "").trim();
    return out;
}

// `ip -br link show type wireguard` → interface names.
function wgLinks(text) {
    return String(text || "").split("\n").map(function (l) { return l.trim().split(/\s+/)[0]; }).filter(function (n) { return n; });
}
