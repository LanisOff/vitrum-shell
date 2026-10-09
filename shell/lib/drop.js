.pragma library
// A bar panel flows out of its island like a drop: the island stretches down
// a short neck, and the panel swells out of the neck's end. niri's shaped glass
// (shape-fillet) melts the pieces into one with concave fillets; the shell
// only says where the pieces are, and paints its tint along the same outline.
//
// Everything here is in the bar's frame: y is the distance from the bar's
// screen edge, so a bottom bar uses the same numbers, mirrored (mirrorRect).

function _clamp01(x) { return Math.max(0, Math.min(1, x)); }
function _smooth(a, b, x) { var t = _clamp01((x - a) / (b - a)); return t * t * (3 - 2 * t); }
function _lerp(a, b, t) { return a + (b - a) * t; }

// island {x,y,w,h}; target {x,w,h} the open panel; t 0 closed … 1 open (may
// overshoot a little). The neck grows first, then the sheet widens and swells.
// radius: the sheet's corners. Under a sheet narrower than the island the
// neck narrows to the sheet's flat top, inside its rounded corners: an
// island-wide neck stuck out past them as two blurred ears. The inset grows
// with the difference, so the neck never jumps.
function dropGeometry(island, target, t, neckLen, radius) {
    var n = neckLen * _smooth(0, 0.35, t);
    var spread = _smooth(0.05, 0.75, Math.min(1, t));
    var w = _lerp(island.w, target.w, spread);
    var cx = _lerp(island.x + island.w / 2, target.x + target.w / 2, spread);
    var top = island.y + island.h + n;
    var nl = island.x, nr = island.x + island.w;
    if (radius > 0 && w < island.w) {
        var inset = radius * _clamp01((island.w - w) / (2 * radius));
        nl = Math.max(nl, cx - w / 2 + inset);
        nr = Math.min(nr, cx + w / 2 - inset);
        if (nr - nl < 1) { var m = (nl + nr) / 2; nl = m - 0.5; nr = m + 0.5; }
    }
    return {
        neck: { x: nl, y: island.y + island.h, w: nr - nl, h: n },
        sheet: { x: cx - w / 2, y: top, w: w, h: Math.max(0, target.h * t) }
    };
}

// A top-frame rect in window coordinates; a bottom bar counts from the bottom.
function mirrorRect(r, mirrored, height) {
    return mirrored ? { x: r.x, y: height - r.y - r.h, w: r.w, h: r.h } : { x: r.x, y: r.y, w: r.w, h: r.h };
}

function _n(v) { return String(Math.round(v * 100) / 100); }

// The outline of island + neck + sheet as an SVG path (window coordinates).
// radius caps every corner (as niri does: min(radius, w/2, h/2)); fillet is the
// concave round where the neck meets the sheet. Mirrored for a bottom bar.
function dropPath(island, sheet, radius, fillet, mirrored, height, neck) {
    if (!(sheet.w > 0.5 && sheet.h > 0.5)) return "";
    var Y = function (y) { return mirrored ? height - y : y; };
    var cvx = mirrored ? "0" : "1", ccv = mirrored ? "1" : "0";
    var out = [];
    var P = function (cmd, x, y) { out.push(cmd + " " + _n(x) + " " + _n(Y(y))); };
    var A = function (r, sweep, x, y) { out.push("A " + _n(r) + " " + _n(r) + " 0 0 " + sweep + " " + _n(x) + " " + _n(Y(y))); };
    var L = function (x, y) { P("L", x, y); };

    var ix = island.x, iy = island.y, iw = island.w, ih = island.h;
    var sx = sheet.x, st = sheet.y, sw = sheet.w, sh = sheet.h;
    var ri = Math.min(radius, iw / 2, ih / 2);
    var rs = Math.min(radius, sw / 2, sh / 2);
    var mr = (sx + sw) - (ix + iw), ml = ix - sx;

    // A sheet no wider than the island: the pieces as they are, no fillets.
    if (mr < -0.5 || ml < -0.5) {
        var rr = function (x, y, w, h, r) {
            P("M", x + r, y); L(x + w - r, y); A(r, cvx, x + w, y + r); L(x + w, y + h - r); A(r, cvx, x + w - r, y + h);
            L(x + r, y + h); A(r, cvx, x, y + h - r); L(x, y + r); A(r, cvx, x + r, y); out.push("Z");
        };
        if (neck && neck.w > 0) {
            // The island, the neck between (into both, square), the sheet.
            rr(ix, iy, iw, ih, ri);
            var ny = iy + ih / 2, nb = st + rs;
            P("M", neck.x, ny); L(neck.x + neck.w, ny); L(neck.x + neck.w, nb); L(neck.x, nb); out.push("Z");
        } else {
            rr(ix, iy, iw, st - iy, ri);
        }
        rr(sx, st, sw, sh, rs);
        return out.join(" ");
    }

    var room = Math.max(0, st - (iy + ri));
    // A side that sticks out less than its own corner reads as flush.
    var fr = Math.min(fillet, Math.max(0, mr - rs), room);
    var fl = Math.min(fillet, Math.max(0, ml - rs), room);

    P("M", ix + ri, iy);
    L(ix + iw - ri, iy);
    A(ri, cvx, ix + iw, iy + ri);
    if (fr > 0) {
        L(ix + iw, st - fr);
        A(fr, ccv, ix + iw + fr, st);
        L(sx + sw - rs, st);
        A(rs, cvx, sx + sw, st + rs);
    }
    L(sx + sw, st + sh - rs);
    A(rs, cvx, sx + sw - rs, st + sh);
    L(sx + rs, st + sh);
    A(rs, cvx, sx, st + sh - rs);
    if (fl > 0) {
        L(sx, st + rs);
        A(rs, cvx, sx + rs, st);
        L(ix - fl, st);
        A(fl, ccv, ix, st - fl);
    }
    L(ix, iy + ri);
    A(ri, cvx, ix + ri, iy);
    out.push("Z");
    return out.join(" ");
}
