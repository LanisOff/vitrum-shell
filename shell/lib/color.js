.pragma library
// Colour maths for the palette and the contrast guard. Colours are
// {r,g,b,a} in 0..1; hex strings are #rgb, #rrggbb or #aarrggbb (Qt's order).

function _clamp(x) { return Math.max(0, Math.min(1, x)); }

function parse(hex) {
    var h = String(hex).replace("#", "");
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    var a = 1;
    if (h.length === 8) { a = parseInt(h.slice(0, 2), 16) / 255; h = h.slice(2); }
    return { r: parseInt(h.slice(0, 2), 16) / 255, g: parseInt(h.slice(2, 4), 16) / 255, b: parseInt(h.slice(4, 6), 16) / 255, a: a };
}

function _hex2(x) { var s = Math.round(_clamp(x) * 255).toString(16); return s.length < 2 ? "0" + s : s; }

function toHex(c) {
    var rgb = _hex2(c.r) + _hex2(c.g) + _hex2(c.b);
    return "#" + (c.a !== undefined && c.a < 1 ? _hex2(c.a) : "") + rgb;
}

function _lin(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }

function luminance(c) { return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b); }

function contrast(a, b) {
    var la = luminance(a), lb = luminance(b);
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

function mix(a, b, t) {
    return { r: a.r + (b.r - a.r) * t, g: a.g + (b.g - a.g) * t, b: a.b + (b.b - a.b) * t, a: (a.a === undefined ? 1 : a.a) + ((b.a === undefined ? 1 : b.a) - (a.a === undefined ? 1 : a.a)) * t };
}

function withAlpha(c, alpha) { return { r: c.r, g: c.g, b: c.b, a: alpha }; }

// Move fg toward white or black — whichever reaches `min` first — in 5% steps.
function ensureContrast(fg, bg, min) {
    if (min === undefined) min = 4.5;
    var f = parse(fg), b = parse(bg);
    if (contrast(f, b) >= min) return fg;
    var white = { r: 1, g: 1, b: 1, a: 1 }, black = { r: 0, g: 0, b: 0, a: 1 };
    for (var i = 1; i <= 20; i++) {
        var t = i * 0.05;
        // Measure the rounded colour: that is what gets drawn.
        var up = toHex(mix(f, white, t)), down = toHex(mix(f, black, t));
        var cu = contrast(parse(up), b), cd = contrast(parse(down), b);
        if (cu >= min || cd >= min) return cu >= cd ? up : down;
    }
    return contrast(white, b) >= contrast(black, b) ? "#ffffff" : "#000000";
}
