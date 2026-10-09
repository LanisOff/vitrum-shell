.pragma library
// The launcher's (Spotlight's) own lookups: symbols by name, the web search
// address, and what a preview can show of a file.

// Every query word in the name; names that begin with the first query word
// come first. all: [{ char, name, group, code }]
function searchSymbols(all, q, limit) {
    var words = String(q || "").toLowerCase().split(/\s+/).filter(function (w) { return w; });
    if (!words.length) return all.slice(0, limit);
    var first = [], rest = [];
    for (var i = 0; i < all.length; i++) {
        var n = all[i].name, ok = true;
        for (var j = 0; j < words.length; j++) if (n.indexOf(words[j]) < 0) { ok = false; break; }
        if (!ok) continue;
        (n.indexOf(words[0]) === 0 ? first : rest).push(all[i]);
    }
    // Names that begin with it, then the rest; shortest names (the plain sign) first.
    var byLen = function (a, b) { return a.name.length - b.name.length; };
    first.sort(byLen); rest.sort(byLen);
    return first.concat(rest).slice(0, limit);
}

// "U+1F44D U+1F3FD": every code point of a sequence.
function codePoints(ch) {
    var out = [], s = String(ch || "");
    for (var i = 0; i < s.length; i++) {
        var c = s.charCodeAt(i);
        if (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length) {
            c = ((c - 0xD800) << 10) + (s.charCodeAt(i + 1) - 0xDC00) + 0x10000;
            i++;
        }
        var h = c.toString(16).toUpperCase();
        while (h.length < 4) h = "0" + h;
        out.push("U+" + h);
    }
    return out.join(" ");
}

function webUrl(template, q) {
    var t = String(template || "") || "https://www.google.com/search?q=%s";
    return t.replace("%s", encodeURIComponent(String(q || "")));
}

function fileKind(path) {
    var p = String(path || "").toLowerCase();
    if (/\.(png|jpe?g|gif|webp|bmp|svg|avif)$/.test(p)) return "image";
    if (/\.(txt|md|markdown|log|conf|cfg|ini|json|ya?ml|toml|kdl|qml|js|mjs|ts|py|sh|bash|fish|rs|c|h|cpp|go|java|lua|css|html|xml|csv)$/.test(p)) return "text";
    return "other";
}
