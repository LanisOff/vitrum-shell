.pragma library
// About this computer: the raw facts SysInfo reads (cpuinfo, lspci, DMI, df,
// niri's outputs) turned into the short words the tiles show. Pure, so it is
// tested (tests/js/about.test.mjs). Missing input gives "" and the tile says
// "Unknown".

function _clean(s) { return String(s || "").replace(/\s+/g, " ").trim(); }

// "AMD Ryzen 5 7500F 6-Core Processor" → "Ryzen 5 7500F",
// "13th Gen Intel(R) Core(TM) i7-13700K" → "Core i7-13700K".
function cpuShort(model) {
    var s = _clean(model)
        .replace(/\((R|TM|tm|r)\)/g, "")
        .replace(/\bCPU\s*@.*$/i, "")
        .replace(/@\s*[\d.]+\s*GHz.*$/i, "")
        .replace(/\bwith Radeon.*$/i, "")
        .replace(/\b\d+-Core\b/gi, "")
        .replace(/\b(Processor|CPU)\b/gi, "")
        .replace(/^\d+(st|nd|rd|th) Gen\b/i, "")
        .replace(/^\s*(AMD|Intel|Qualcomm( Technologies, Inc)?)\b/i, "");
    return _clean(s);
}

// lspci's VGA / 3D lines (one per line, the part after the class) → the one to
// show: a discrete card (NVIDIA, then AMD) over an integrated Intel one.
function gpuPick(text) {
    var lines = String(text || "").split("\n").map(_clean).filter(function (l) { return l.length > 0; });
    if (lines.length === 0) return "";
    var rank = function (l) { return /nvidia/i.test(l) ? 0 : /amd|ati\b|advanced micro/i.test(l) ? 1 : /intel/i.test(l) ? 3 : 2; };
    var best = lines[0];
    for (var i = 1; i < lines.length; i++) if (rank(lines[i]) < rank(best)) best = lines[i];
    return best;
}

// "NVIDIA Corporation AD107 [GeForce RTX 4060] (rev a1)" → "RTX 4060";
// "… Navi 31 [Radeon RX 7900 XTX] (rev c8)" → "RX 7900 XTX".
function gpuShort(line) {
    var s = _clean(line).replace(/\s*\(rev [0-9a-f]+\)\s*$/i, "");
    if (!s) return "";
    var br = s.match(/\[([^\]]+)\]/g);
    var name = "";
    if (br) {
        // The last bracket is the marketing name; [AMD/ATI] is the vendor.
        for (var i = br.length - 1; i >= 0; i--) {
            var b = br[i].slice(1, -1);
            if (!/^AMD\/ATI$/i.test(b)) { name = b; break; }
        }
        // "GeForce RTX 4060 Ti / …" alternatives: the first.
        name = name.split(" / ")[0];
    }
    if (!name) name = s.replace(/^(NVIDIA Corporation|Advanced Micro Devices, Inc\.|Intel Corporation)\s*/i, "");
    return _clean(name.replace(/^GeForce\s+(?=(RTX|GTX|GT|MX)\b)/i, "").replace(/^Radeon\s+(?=RX\b)/i, ""));
}

function gpuVendor(line) {
    var s = String(line || "");
    if (/nvidia/i.test(s)) return "NVIDIA";
    if (/advanced micro|amd|\bati\b/i.test(s)) return "AMD";
    if (/intel/i.test(s)) return "Intel";
    if (/virtio|red hat/i.test(s)) return "Virtio";
    if (/vmware/i.test(s)) return "VMware";
    return "";
}

// Decimal sizes, as Disk Utility and the box say: 950 GB, 1.9 TB, 512 MB.
function size(bytes) {
    var v = Number(bytes) || 0;
    if (v <= 0) return "";
    var u = ["B", "KB", "MB", "GB", "TB", "PB"], i = 0;
    while (v >= 1000 && i < u.length - 1) { v /= 1000; i++; }
    return (v >= 10 || i === 0 ? Math.round(v) : Math.round(v * 10) / 10) + " " + u[i];
}

// VRAM in MiB (nvidia-smi) → "8 GB": cards are sold in binary gigabytes.
function vram(mib) {
    var m = Number(mib) || 0;
    if (m <= 0) return "";
    var g = m / 1024;
    return (g >= 1 ? Math.round(g) + " GB" : Math.round(m) + " MB");
}

// "241 GB used · 709 GB free"
function diskLine(used, avail) {
    var a = size(used), b = size(avail);
    if (!a && !b) return "";
    return [a ? a + " used" : "", b ? b + " free" : ""].filter(function (s) { return s; }).join(" · ");
}

// 0..1, or 0 without a size.
function diskUsage(used, total) {
    var u = Number(used) || 0, t = Number(total) || 0;
    return t > 0 ? Math.max(0, Math.min(1, u / t)) : 0;
}

// Seconds up → "1d 5h", "5h 12m", "12m", "0m".
function uptimeShort(sec) {
    var s = Math.max(0, Math.floor(Number(sec) || 0));
    if (!s) return "";
    var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
    if (d > 0) return d + "d " + h + "h";
    if (h > 0) return h + "h " + m + "m";
    return m + "m";
}

// Memory: "31 GB" from GiB (what /proc/meminfo gives, less the reserved bit).
function memory(gib) {
    var g = Number(gib) || 0;
    return g > 0 ? Math.round(g) + " GB" : "";
}

// "DDR5", "6000 MT/s" → "DDR5 · 6000 MT/s"; DMI's Unknown / Other say nothing.
function memorySub(type, speed) {
    var t = _clean(type), sp = _clean(speed);
    if (/^(unknown|other|undefined)$/i.test(t)) t = "";
    if (/^(unknown|0( MT\/s)?)$/i.test(sp)) sp = "";
    if (/^\d+$/.test(sp)) sp += " MT/s";
    return [t, sp].filter(function (x) { return x; }).join(" · ");
}

// DMI's makers, as people say them.
function vendorShort(v) {
    var s = _clean(v);
    if (!s || /^(to be filled|default string|system manufacturer|o\.?e\.?m\.?|not applicable|none)/i.test(s)) return "";
    var known = [[/micro-star|^msi\b/i, "MSI"], [/asustek|^asus/i, "ASUS"], [/gigabyte/i, "Gigabyte"], [/asrock/i, "ASRock"],
                 [/^lenovo/i, "Lenovo"], [/^dell/i, "Dell"], [/hewlett|^hp\b/i, "HP"], [/^acer/i, "Acer"], [/apple/i, "Apple"],
                 [/framework/i, "Framework"], [/^qemu/i, "QEMU"], [/innotek|virtualbox/i, "VirtualBox"], [/vmware/i, "VMware"],
                 [/microsoft/i, "Microsoft"], [/samsung/i, "Samsung"], [/biostar/i, "Biostar"], [/supermicro/i, "Supermicro"]];
    for (var i = 0; i < known.length; i++) if (known[i][0].test(s)) return known[i][1];
    return _clean(s.replace(/,?\s*(Co\.,?\s*)?(Ltd\.?|Inc\.?|Corporation|Corp\.?|GmbH|LLC|Limited|Technology|Computer)\b\.?/gi, ""));
}

// The board: its chipset where the name has one ("MAG B650 TOMAHAWK WIFI" →
// "B650"), else the name itself (a laptop: "ThinkPad X1 Carbon Gen 11").
function boardShort(name) {
    var s = _clean(name).replace(/\s*\(MS-\w+\)\s*$/i, "");
    if (!s || /^(to be filled|default string|system product name|not applicable)/i.test(s)) return "";
    var m = s.match(/\b([ABHXZQW]\d{3}[EMI]?)\b/);
    return m ? m[1] : s;
}

// The board's full name: vendor and model, without the vendor said twice.
function boardFull(vendor, name) {
    var v = vendorShort(vendor), n = _clean(name);
    if (/^(to be filled|default string|system product name|not applicable)/i.test(n)) n = "";
    if (!n) return v;
    if (!v || n.toLowerCase().indexOf(v.toLowerCase()) === 0) return n;
    return v + " " + n;
}

// "MSI · firmware 1.30"
function boardSub(vendor, firmware) {
    var v = vendorShort(vendor), f = _clean(firmware);
    return [v, f ? "firmware " + f : ""].filter(function (x) { return x; }).join(" · ");
}

// Displays [{ width, height }] → "2 × 1920×1080", or "2560×1440 + 1920×1080".
function displaysLine(list) {
    var on = (list || []).filter(function (d) { return d && d.width > 0 && d.height > 0; });
    if (on.length === 0) return "";
    var res = on.map(function (d) { return d.width + "×" + d.height; });
    var same = res.every(function (r) { return r === res[0]; });
    if (on.length > 1 && same) return on.length + " × " + res[0];
    return res.join(" + ");
}

// The line under it: refresh rates ("60 Hz", "144 + 60 Hz") and the screens' models.
function displaysSub(list) {
    var on = (list || []).filter(function (d) { return d && d.width > 0; });
    if (on.length === 0) return "";
    var hz = [];
    on.forEach(function (d) { if (d.refresh > 0 && hz.indexOf(d.refresh) < 0) hz.push(d.refresh); });
    var models = on.map(function (d) { return _clean(d.model); }).filter(function (m) { return m && !/^unknown$/i.test(m); });
    return [hz.length ? hz.join(" + ") + " Hz" : "", models.join(" + ")].filter(function (x) { return x; }).join(" · ");
}

// The screens' layout scaled into a w×h box: [{ name, x, y, width, height,
// primary }], centred, keeping the proportions of niri's logical layout.
// `primary` names the lit one (the focused output); without it the screen at
// the top left. Screens without a position are laid out in a row.
function layout(list, w, h, primary) {
    var on = (list || []).filter(function (d) { return d && (d.logicalWidth || d.width) > 0; });
    if (on.length === 0 || !(w > 0) || !(h > 0)) return [];
    var placed = on.some(function (d) { return d.x !== undefined && d.y !== undefined && (d.x !== 0 || d.y !== 0); });
    var cx = 0, rects = on.map(function (d) {
        var rw = d.logicalWidth || d.width, rh = d.logicalHeight || d.height;
        var r = { name: d.name || "", x: placed ? (d.x || 0) : cx, y: placed ? (d.y || 0) : 0, width: rw, height: rh };
        cx += rw;
        return r;
    });
    var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    rects.forEach(function (r) { minX = Math.min(minX, r.x); minY = Math.min(minY, r.y); maxX = Math.max(maxX, r.x + r.width); maxY = Math.max(maxY, r.y + r.height); });
    var k = Math.min(w / (maxX - minX), h / (maxY - minY));
    var ox = (w - (maxX - minX) * k) / 2, oy = (h - (maxY - minY) * k) / 2;
    var lit = -1;
    for (var i = 0; i < rects.length; i++) if (primary && rects[i].name === primary) lit = i;
    if (lit < 0) {
        lit = 0;
        for (var j = 1; j < rects.length; j++) {
            var a = rects[j], b = rects[lit];
            if (a.y < b.y || (a.y === b.y && a.x < b.x)) lit = j;
        }
    }
    return rects.map(function (r, n) {
        return { name: r.name, x: ox + (r.x - minX) * k, y: oy + (r.y - minY) * k, width: r.width * k, height: r.height * k, primary: n === lit };
    });
}

// "CachyOS · niri 26.04 · vitrum 0.5.0", without the parts not known; niri's
// build in brackets ("26.04 (8ed0da4-modified)") stays for the copied details.
function subtitle(distro, niri, vitrum) {
    var n = _clean(niri).replace(/\s*\(.*\)\s*$/, "");
    return [_clean(distro), n ? "niri " + n : "", vitrum ? "vitrum " + _clean(vitrum) : ""]
        .filter(function (x) { return x; }).join(" · ");
}
