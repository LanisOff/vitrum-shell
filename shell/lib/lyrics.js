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

// curl arguments for lrclib's /api/get, or null when there is nothing to ask.
function queryArgs(track) {
    var title = cleanTitle(track.title), artist = cleanArtist(track.artist);
    if (!title || !artist) return null;
    var a = ["--data-urlencode", "artist_name=" + artist, "--data-urlencode", "track_name=" + title];
    // No album: players disagree on it (singles, compilations) and lrclib wants it exact.
    if (track.length > 0) a = a.concat(["--data-urlencode", "duration=" + Math.round(track.length)]);
    return a;
}
