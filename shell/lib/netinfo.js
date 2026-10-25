.pragma library
// The Network info widget's readings: the address this machine goes out
// from (`ip route get`), and the public address a lookup service sees.

function isIPv4(s) {
    var m = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(String(s || ""));
    if (!m) return false;
    for (var i = 1; i <= 4; i++) if (Number(m[i]) > 255) return false;
    return true;
}
function isIPv6(s) {
    var t = String(s || "");
    if (!/^[0-9a-fA-F:]+$/.test(t) || t.indexOf(":") < 0 || t.length < 2 || t.length > 39) return false;
    var dbl = t.split("::").length - 1;
    if (dbl > 1) return false;
    var groups = t.split(":").filter(function (g) { return g.length > 0; });
    if (groups.some(function (g) { return g.length > 4; })) return false;
    return dbl === 1 ? groups.length < 8 : groups.length === 8;
}
function isIp(s) { return isIPv4(s) || isIPv6(s); }

/// `ip -o route get <addr>` → { ip, dev } (the source address and the interface).
function routeSrc(text) {
    var t = String(text || "");
    var src = /\bsrc\s+(\S+)/.exec(t), dev = /\bdev\s+(\S+)/.exec(t);
    var ip = src && isIp(src[1]) ? src[1] : "";
    return { ip: ip, dev: ip && dev ? dev[1] : "" };
}

/// A lookup service's reply (a bare address, maybe with a newline) → the address, or "".
function publicIp(text) {
    var t = String(text || "").trim();
    return isIp(t) ? t : "";
}

/// The shell command that prints the outgoing route, IPv4 first.
function routeCommand() {
    return "ip -o -4 route get 1.1.1.1 2>/dev/null || ip -o -6 route get 2606:4700:4700::1111 2>/dev/null";
}
/// The shell command that asks for the public address: two services, short timeouts.
function publicCommand() {
    return "curl -fsS --connect-timeout 4 --max-time 8 https://api.ipify.org || curl -fsS --connect-timeout 4 --max-time 8 https://ifconfig.me/ip";
}
