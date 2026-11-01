.pragma library
// Synced lyrics: LRC text from lrclib.net → timed lines, and the line playing now.

var STAMP = /\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]/g;

// "[mm:ss.xx] text" lines → [{t: seconds, text}], sorted. Tags like [ar: …] are dropped.
function parseLrc(text) {
    var out = [];
    String(text || "").split(/\r?\n/).forEach(function (line) {
        var stamps = [], m, last = 0;
        STAMP.lastIndex = 0;
        while ((m = STAMP.exec(line)) !== null && m.index === last) {
            var frac = m[3] ? parseFloat("0." + m[3]) : 0;
            stamps.push(parseInt(m[1], 10) * 60 + parseInt(m[2], 10) + frac);
            last = STAMP.lastIndex;
        }
        if (!stamps.length) return;
        var body = line.slice(last).trim();
        stamps.forEach(function (t) { out.push({ t: Math.round(t * 1000) / 1000, text: body }); });
    });
    out.sort(function (a, b) { return a.t - b.t; });
    return out;
}

// Index of the line playing at `pos` seconds: the last that started; -1 before the first.
function lineAt(lines, pos) {
    var lo = 0, hi = lines.length - 1, found = -1;
    while (lo <= hi) {
        var mid = (lo + hi) >> 1;
        if (lines[mid].t <= pos) { found = mid; lo = mid + 1; } else hi = mid - 1;
    }
    return found;
}

function cleanTitle(s) {
    return String(s || "").replace(/\s*[\(\[][^\)\]]*(official|video|audio|lyrics?|visualizer|hd|4k|remaster)[^\)\]]*[\)\]]/gi, "").trim();
}
function cleanArtist(s) { return String(s || "").replace(/\s*-\s*Topic$/i, "").trim(); }

// The song itself, without what only this release adds: "Song - Remastered 2011",
// "Song (feat. Someone)", "Song [Live]".
function baseTitle(s) {
    return cleanTitle(s)
        .replace(/\s*[\(\[][^\)\]]*(feat\.?|ft\.?|with |remix|remaster|live|version|edit|mix|deluxe|bonus)[^\)\]]*[\)\]]/gi, "")
        .replace(/\s+-\s+.*(remaster|remix|live|version|edit|mix|deluxe|bonus).*$/i, "")
        .trim();
}
// The main artist of "A, B", "A & B", "A feat. B".
function firstArtist(s) {
    return cleanArtist(s).split(/\s*(?:,|;|&|\/|\bfeat\.?|\bft\.?|\bfeaturing\b|\bx\b|\bи\b)\s*/i)[0].trim() || cleanArtist(s);
}

function _ask(path, q) {
    var parts = [];
    for (var k in q) parts.push(k + "=" + encodeURIComponent(q[k]));
    return path + "?" + parts.join("&");
}

// What to ask lrclib, best first: URLs under /api/. The exact signature, then
// its plainer form, then a search that does not depend on the length matching
// (a video's length never does). [] when there is nothing to ask.
function attempts(track) {
    var title = cleanTitle(track.title), artist = cleanArtist(track.artist);
    if (!title) return [];
    var base = baseTitle(title), first = firstArtist(artist), out = [];
    function add(a) { if (out.indexOf(a) < 0) out.push(a); }
    if (artist) {
        // No album: players disagree on it (singles, compilations) and lrclib wants it exact.
        if (track.length > 0) {
            var len = Math.round(track.length);
            add(_ask("get", { artist_name: artist, track_name: title, duration: len }));
            add(_ask("get", { artist_name: first, track_name: base, duration: len }));
        }
        add(_ask("search", { track_name: base, artist_name: first }));
    }
    // A video's title: "Artist - Song", the channel being someone else.
    var dash = /^(.+?)\s+[-–—]\s+(.+)$/.exec(base);
    if (dash) add(_ask("search", { track_name: dash[2], artist_name: firstArtist(dash[1]) }));
    add(_ask("search", { q: (first ? first + " " : "") + base }));
    return out;
}

// One run's output: a line per answer, "<http code or cached>\t<json>".
// → { cached, flaky (lrclib did not really answer: not a miss), items: [records] }
function parseAnswers(text) {
    var out = { cached: false, flaky: false, items: [] };
    String(text || "").split("\n").forEach(function (line) {
        var tab = line.indexOf("\t");
        if (tab < 0) return;
        var code = line.slice(0, tab), body = line.slice(tab + 1);
        if (code === "cached") out.cached = true;
        else if (code !== "200" && code !== "404") { out.flaky = true; return; }
        var d = null;
        try { d = JSON.parse(body); } catch (e) { return; }
        (Array.isArray(d) ? d : [d]).forEach(function (r) { if (r && typeof r === "object") out.items.push(r); });
    });
    return out;
}

function _plain(s) { return String(s || "").toLowerCase().replace(/[\s!-\/:-@\[-`{-~«»—–…’‘“”]+/g, " ").trim(); }

// A search also returns other songs: the title has to be this one.
function _sameSong(record, track) {
    var a = _plain(record.trackName), b = _plain(baseTitle(track.title));
    if (!record.trackName) return true;      // what was kept in the cache
    return !!a && !!b && (a === b || (" " + b + " ").indexOf(" " + a + " ") >= 0 || (" " + a + " ").indexOf(" " + b + " ") >= 0);
}

// How far timed lines may run from what plays and still be sung along.
var MAX_DRIFT = 8;

// The best of the answers → { syncedLyrics, plainLyrics }, or null. Timed lines
// of another cut would run ahead of the singer, so those count as plain text.
function best(items, track) {
    var len = track.length > 0 ? track.length : 0, out = null, top = -Infinity;
    (items || []).forEach(function (r) {
        if (!r || !(r.syncedLyrics || r.plainLyrics) || !_sameSong(r, track)) return;
        var off = len && r.duration > 0 ? Math.abs(r.duration - len) : 0;
        var synced = r.syncedLyrics && off <= MAX_DRIFT ? r.syncedLyrics : "";
        var score = (synced ? 1000 : 0) - off;
        if (score <= top) return;
        top = score;
        out = { syncedLyrics: synced, plainLyrics: r.plainLyrics || (r.syncedLyrics ? r.syncedLyrics.replace(/\[[\d:.]+\]\s*/g, "") : "") };
    });
    return out;
}

// What the cache keeps: the lyrics; with "checked" when they could get better
// (plain text, nothing), so that the track is asked again some day.
function cacheRecord(found, now) {
    if (found && found.syncedLyrics) return found;
    return { plainLyrics: found ? found.plainLyrics : "", checked: now };
}
