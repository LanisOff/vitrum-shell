import { load, eq } from "./lib.mjs";
const v = load("vpn.js");

const t = v.parseThrone("[Tun+System Proxy]\nThrone\n[Shadowsocks] LV / Shadowsocks@xeovo\n🇱🇻 Latvia, Riga");
eq(t.tun, true, "tun on");
eq(t.proxy, true, "system proxy on");
eq(t.protocol, "Shadowsocks", "protocol");
eq(t.server, "LV / Shadowsocks@xeovo", "server");
eq(t.place, "🇱🇻 Latvia, Riga", "where");
eq(t.short, "Latvia, Riga", "the place without the flag, for the bar");

const off = v.parseThrone("Throne\n[Hysteria] US-SLC / Hysteria2@xeovo");
eq(off.tun, false, "no mode line: off");
eq(off.server, "US-SLC / Hysteria2@xeovo", "server still known");

const proxyOnly = v.parseThrone("[System Proxy]\nThrone");
eq(proxyOnly.tun, false, "proxy only is not the tunnel");
eq(proxyOnly.proxy, true, "proxy");

eq(v.parseThrone("").tun, false, "nothing");

// WireGuard links from `ip -br link show type wireguard`.
eq(JSON.stringify(v.wgLinks("wg0              UNKNOWN        <POINTOPOINT,NOARP,UP,LOWER_UP>\nhome UP <...>\n")), JSON.stringify(["wg0", "home"]), "links");
eq(JSON.stringify(v.wgLinks("")), "[]", "none");
