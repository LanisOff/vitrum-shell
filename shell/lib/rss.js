.pragma library
// Feeds for the Headlines widget: RSS 2.0, RSS 1.0 (RDF) and Atom, read
// with plain patterns (QML has no XML parser for text that came from a
// Process), into { title, link, time, source } items.

// Between feeds in the fetcher's output: a line SEP + url, then that feed's body.
var SEP = "\u001e";

var _NAMED = { amp: "&", lt: "<", gt: ">", quot: "\"", apos: "'", nbsp: " ", ndash: "–", mdash: "—",
               hellip: "…", lsquo: "‘", rsquo: "’", ldquo: "“", rdquo: "”", laquo: "«", raquo: "»",
               middot: "·", bull: "•", copy: "©", reg: "®", trade: "™", euro: "€", pound: "£" };

/// Character references → characters; an unknown named one stays as it is.
function decode(s) {
    return String(s || "").replace(/&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);/g, function (m, e) {
        if (e.charAt(0) === "#") {
            var n = e.charAt(1) === "x" || e.charAt(1) === "X" ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
            return isFinite(n) && n > 0 && n <= 0x10ffff ? String.fromCodePoint(n) : "";
        }
        return _NAMED.hasOwnProperty(e) ? _NAMED[e] : m;
    });
}

var _TAG = /<\/?[a-zA-Z][^<>]*>/g;
/// An element's content as plain text: CDATA unwrapped, markup and
/// references gone (an escaped <b> in a title too), whitespace folded.
function text(raw) {
    var s = String(raw || "").replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, function (m, c) { return c.replace(_TAG, ""); });
    s = decode(s.replace(_TAG, "")).replace(_TAG, "");
    return s.replace(/\s+/g, " ").trim();
}

function _re(name) { return name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); }
/// The raw content of the first <name>…</name> in `xml` ("" if none).
function tag(xml, name) {
    var m = new RegExp("<" + _re(name) + "(?:\\s[^>]*)?>([\\s\\S]*?)</" + _re(name) + "\\s*>", "i").exec(String(xml || ""));
    return m ? m[1] : "";
}
/// Every <name>…</name>'s content (not <names>: the name must end there).
function blocks(xml, name) {
    var re = new RegExp("<" + _re(name) + "(?:\\s[^>]*)?>([\\s\\S]*?)</" + _re(name) + "\\s*>", "gi"), out = [], m;
    while ((m = re.exec(String(xml || ""))) !== null) out.push(m[1]);
    return out;
}
function attr(tagText, name) {
    var m = new RegExp("\\s" + _re(name) + "\\s*=\\s*(\"([^\"]*)\"|'([^']*)')", "i").exec(String(tagText || ""));
    return m ? decode(m[2] !== undefined ? m[2] : m[3]) : "";
}
// Atom: the rel="alternate" link (or one with no rel), else the first.
function _atomLink(entry) {
    var links = String(entry).match(/<link\b[^>]*>/gi) || [], first = "";
    for (var i = 0; i < links.length; i++) {
        var href = attr(links[i], "href"), rel = attr(links[i], "rel");
        if (!href) continue;
        if (!first) first = href;
        if (!rel || rel === "alternate") return href;
    }
    return first;
}

var _MONTHS = { jan: 0, feb: 1, mar: 2, apr: 3, may: 4, jun: 5, jul: 6, aug: 7, sep: 8, oct: 9, nov: 10, dec: 11 };
var _ZONES = { ut: 0, utc: 0, gmt: 0, z: 0, est: -300, edt: -240, cst: -360, cdt: -300, mst: -420, mdt: -360, pst: -480, pdt: -420 };
function _offset(z) {
    if (!z) return 0;
    var m = /^([+-])(\d{2}):?(\d{2})$/.exec(z);
    if (m) return (m[1] === "-" ? -1 : 1) * (Number(m[2]) * 60 + Number(m[3]));
    var k = z.toLowerCase();
    return _ZONES.hasOwnProperty(k) ? _ZONES[k] : 0;
}
/// RFC 822 (RSS) or ISO 8601 (Atom, dc:date) → ms since the epoch; 0 when unreadable.
function parseDate(s) {
    var t = String(s || "").trim(), m;
    m = /^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?)?\s*(Z|[+-]\d{2}:?\d{2})?$/i.exec(t);
    if (m) return Date.UTC(+m[1], +m[2] - 1, +m[3], +(m[4] || 0), +(m[5] || 0), +(m[6] || 0)) - _offset(m[7]) * 60000;
    m = /(\d{1,2})\s+([A-Za-z]{3})[A-Za-z]*\.?\s+(\d{2,4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([A-Za-z]{1,4}|[+-]\d{4})?/.exec(t);
    if (m && _MONTHS.hasOwnProperty(m[2].toLowerCase())) {
        var y = +m[3];
        if (y < 100) y += y < 50 ? 2000 : 1900;
        return Date.UTC(y, _MONTHS[m[2].toLowerCase()], +m[1], +m[4], +m[5], +(m[6] || 0)) - _offset(m[7]) * 60000;
    }
    return 0;
}

function host(url) {
    var m = /^[a-z][a-z0-9+.-]*:\/\/([^\/?#:]+)/i.exec(String(url || ""));
    return m ? m[1].replace(/^www\./i, "").toLowerCase() : "";
}
/// What a feed is called on a headline: its title's first part ("Ars Technica
/// - All content" → "Ars Technica"), or the site's host.
function shortSource(title, url) {
    var t = String(title || "").trim();
    if (t) {
        var cut = t.split(/\s+[-–—|:·]\s+|:\s+/)[0].trim();
        t = cut || t;
        return t.length > 28 ? t.slice(0, 27) + "…" : t;
    }
    return host(url);
}

/// One feed's text → { title, source, items: [{ title, link, time, source }], error }.
function parseFeed(xml, url) {
    var x = String(xml || "");
    var atom = /<feed[\s>]/i.test(x) && !/<rss[\s>]|<rdf:RDF[\s>]/i.test(x);
    var rss = /<rss[\s>]|<rdf:RDF[\s>]|<channel[\s>]/i.test(x);
    if (!atom && !rss) return { title: "", source: host(url), items: [], error: x.trim() ? "Not a feed" : "Empty reply" };
    var head = x.split(atom ? /<entry[\s>]/i : /<item[\s>]/i)[0];
    var title = text(tag(head, "title"));
    var source = shortSource(title, url);
    var raw = blocks(x, atom ? "entry" : "item"), items = [];
    for (var i = 0; i < raw.length; i++) {
        var b = raw[i];
        var t = text(tag(b, "title"));
        var link = atom ? _atomLink(b) : text(tag(b, "link"));
        // RSS without <link>: a guid that is a permalink (the default), or a link's href.
        if (!link && !atom) {
            var g = b.match(/<guid\b[^>]*>/i);
            if (!g || attr(g[0], "isPermaLink") !== "false") link = text(tag(b, "guid"));
        }
        if (!link && !atom) link = _atomLink(b);
        var when = atom ? (tag(b, "updated") || tag(b, "published")) : (tag(b, "pubDate") || tag(b, "dc:date") || tag(b, "updated"));
        if (!t) continue;
        items.push({ title: t, link: /^https?:\/\//i.test(link) ? link : "", time: parseDate(text(when)), source: source });
    }
    return { title: title, source: source, items: items, error: items.length ? "" : "No headlines" };
}

/// The fetcher's output (SEP url \n body, per feed) → [{ url, body }].
function splitFeeds(out) {
    var parts = String(out || "").split(SEP), list = [];
    for (var i = 1; i < parts.length; i++) {
        var nl = parts[i].indexOf("\n");
        list.push({ url: (nl < 0 ? parts[i] : parts[i].slice(0, nl)).trim(), body: nl < 0 ? "" : parts[i].slice(nl + 1) });
    }
    return list;
}

/// Headlines from several feeds: newest first (undated ones after, in their
/// feed's order), the same link or title only once, at most `limit`.
function merge(feeds, limit) {
    var all = [], seen = {};
    for (var f = 0; f < (feeds || []).length; f++) {
        var items = (feeds[f] && feeds[f].items) || [];
        for (var i = 0; i < items.length; i++) {
            var it = items[i], key = (it.link || it.title).toLowerCase();
            if (seen[key]) continue;
            seen[key] = true;
            all.push({ it: it, order: f * 10000 + i });
        }
    }
    all.sort(function (a, b) {
        var ta = a.it.time || 0, tb = b.it.time || 0;
        if (ta && tb && ta !== tb) return tb - ta;
        if (!ta !== !tb) return ta ? -1 : 1;
        return a.order - b.order;
    });
    return all.slice(0, limit > 0 ? limit : all.length).map(function (x) { return x.it; });
}

/// How long ago, short: "now", "12m", "3h", "2d"; "" when unknown.
function age(time, now) {
    if (!time) return "";
    var m = Math.floor(Math.max(0, now - time) / 60000);
    if (m < 1) return "now";
    if (m < 60) return m + "m";
    var h = Math.floor(m / 60);
    if (h < 24) return h + "h";
    var d = Math.floor(h / 24);
    return d < 14 ? d + "d" : Math.floor(d / 7) + "w";
}

/// The option's list → the feed URLs worth asking: http(s), trimmed, once each, ten at most.
function urls(list) {
    var out = [];
    for (var i = 0; i < (list || []).length; i++) {
        var u = String(list[i] || "").trim();
        if (/^https?:\/\/[^\s'"]+$/i.test(u) && out.indexOf(u) < 0) out.push(u);
    }
    return out.slice(0, 10);
}
