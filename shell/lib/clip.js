.pragma library
// The clipboard history as cliphist lists it: one "<id>\t<preview>" line per
// entry, newest first; a picture's preview is "[[ binary data 2 MiB png 1920x1080 ]]".

var _IMAGE = /^\[\[ binary data .* (png|jpe?g|gif|webp|bmp) /i;

// → [{ id, preview, isImage }], at most `limit` (none: all).
function parseList(text, limit) {
    var out = [], lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        if (limit !== undefined && out.length >= limit) break;
        var line = lines[i];
        if (!line) continue;
        var tab = line.indexOf("\t");
        if (tab < 0) continue;
        var preview = line.substring(tab + 1);
        out.push({ id: line.substring(0, tab), preview: preview, isImage: _IMAGE.test(preview) });
    }
    return out;
}

// A picture entry's kind and size: { type: "PNG", size: "2 MiB", w, h }, or null.
function imageInfo(preview) {
    var m = /binary data (.+?) (png|jpe?g|gif|webp|bmp)(?: (\d+)x(\d+))?/i.exec(String(preview || ""));
    if (!m) return null;
    return { type: m[2].toUpperCase().replace("JPG", "JPEG"), size: m[1], w: m[3] ? +m[3] : 0, h: m[4] ? +m[4] : 0 };
}

// A text entry on one line: runs of white space (newlines, tabs) as one space.
function oneLine(preview) { return String(preview || "").replace(/\s+/g, " ").trim(); }
