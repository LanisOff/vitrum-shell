.pragma library
// The Mixer widget's rows: an app's streams (a browser's tabs, a game's
// sounds) are one row, named and pictured once, its volume the loudest of
// them and muted only when all of them are.

/// entries [{ app, icon, volume, muted }] (one per stream, in order) →
/// [{ app, icon, volume, muted, members: [index…] }] in order of first appearance.
function group(entries) {
    var rows = [], at = {};
    for (var i = 0; i < (entries || []).length; i++) {
        var e = entries[i];
        if (!e) continue;
        var key = String(e.app || "").toLowerCase();
        if (!at.hasOwnProperty(key)) {
            at[key] = rows.length;
            rows.push({ app: e.app || "An app", icon: e.icon || "", volume: 0, muted: true, members: [] });
        }
        var r = rows[at[key]];
        r.members.push(i);
        r.volume = Math.max(r.volume, Number(e.volume) || 0);
        r.muted = r.muted && !!e.muted;
        if (!r.icon && e.icon) r.icon = e.icon;
    }
    return rows;
}

/// How many rows of `rowH` fit in `height` with `spacing` between; when not
/// all `count` do, one of them makes way for an "and N more" line.
function fit(count, height, rowH, spacing) {
    var n = Math.max(0, Math.floor((height + spacing) / (rowH + spacing)));
    if (count <= n) return { rows: count, more: 0 };
    var rows = Math.max(0, n - 1);
    return { rows: rows, more: count - rows };
}
