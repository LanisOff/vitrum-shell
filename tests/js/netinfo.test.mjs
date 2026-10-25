import { load, eq } from "./lib.mjs";
const n = load("netinfo.js");
const j = JSON.stringify;

eq(n.isIPv4("192.168.1.20"), true, "v4");
eq(n.isIPv4("256.1.1.1"), false, "v4 out of range");
eq(n.isIPv4("1.2.3"), false, "v4 too short");
eq(n.isIPv6("2001:db8::1"), true, "v6 shortened");
eq(n.isIPv6("fe80:0:0:0:200:f8ff:fe21:67cf"), true, "v6 full");
eq(n.isIPv6("2001::db8::1"), false, "v6 two ::");
eq(n.isIPv6("12345::1"), false, "v6 group too long");
eq(n.isIPv6("1:2:3:4:5:6:7"), false, "v6 seven groups, no ::");
eq(n.isIp("<html>"), false, "not an address");

eq(j(n.routeSrc("1.1.1.1 via 192.168.200.1 dev enp12s0 src 192.168.200.55 uid 1000 \\    cache ")), j({ ip: "192.168.200.55", dev: "enp12s0" }), "route: source and device");
eq(j(n.routeSrc("2606:4700:4700::1111 from :: via fe80::1 dev wlan0 proto ra src 2001:db8::5 metric 600 pref medium")), j({ ip: "2001:db8::5", dev: "wlan0" }), "route: IPv6");
eq(j(n.routeSrc("")), j({ ip: "", dev: "" }), "route: offline");
eq(j(n.routeSrc("RTNETLINK answers: Network is unreachable")), j({ ip: "", dev: "" }), "route: unreachable");

eq(n.publicIp("203.0.113.7\n"), "203.0.113.7", "public: trimmed");
eq(n.publicIp("<html>rate limited</html>"), "", "public: not an address");
eq(n.publicIp(""), "", "public: nothing");
eq(n.routeCommand().indexOf("route get") > 0, true, "the route command");
eq(n.publicCommand().indexOf("https://") > 0, true, "the lookup goes over https");
