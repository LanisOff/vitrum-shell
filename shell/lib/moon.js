.pragma library
// The moon: its phase now and the dates of the next principal phases.
// Meeus, Astronomical Algorithms (2nd ed.): ch. 49 for the phases' true
// times (to about a minute), ch. 48 (the low-precision phase angle) for the
// lit fraction (to about 0.5%). Times are Date objects (UTC inside, shown in
// local time by whoever formats them).

var SYNODIC = 29.530588861;
var DELTA_T = 69 / 86400;            // TT − UT in the 2020s, in days: close enough for minutes

function _rad(d) { return d * Math.PI / 180; }
function _norm(d) { d = d % 360; return d < 0 ? d + 360 : d; }
function toJD(date) { return date.getTime() / 86400000 + 2440587.5; }
function fromJD(jd) { return new Date(Math.round((jd - 2440587.5) * 86400000)); }

// The true time (JDE, dynamical time) of phase k: an integer k is a new moon,
// k + 0.25 the first quarter, + 0.5 the full moon, + 0.75 the last quarter
// (k = 0 is the new moon of 6 January 2000).
function phaseJDE(k) {
    var T = k / 1236.85, T2 = T * T, T3 = T2 * T, T4 = T3 * T;
    var jde = 2451550.09766 + SYNODIC * k + 0.00015437 * T2 - 0.000000150 * T3 + 0.00000000073 * T4;
    var E = 1 - 0.002516 * T - 0.0000074 * T2, E2 = E * E;
    var M = _rad(2.5534 + 29.10535670 * k - 0.0000014 * T2 - 0.00000011 * T3);
    var Mp = _rad(201.5643 + 385.81693528 * k + 0.0107582 * T2 + 0.00001238 * T3 - 0.000000058 * T4);
    var F = _rad(160.7108 + 390.67050284 * k - 0.0016118 * T2 - 0.00000227 * T3 + 0.000000011 * T4);
    var O = _rad(124.7746 - 1.56375588 * k + 0.0020672 * T2 + 0.00000215 * T3);
    var s = Math.sin, c = Math.cos;
    var f = k - Math.floor(k), q = Math.round(f * 4) % 4;       // 0 new, 1 first, 2 full, 3 last
    var x;
    if (q === 0 || q === 2) {
        var nw = q === 0;
        x = (nw ? -0.40720 : -0.40614) * s(Mp)
          + (nw ? 0.17241 : 0.17302) * E * s(M)
          + (nw ? 0.01608 : 0.01614) * s(2 * Mp)
          + (nw ? 0.01039 : 0.01043) * s(2 * F)
          + (nw ? 0.00739 : 0.00734) * E * s(Mp - M)
          + (nw ? -0.00514 : -0.00515) * E * s(Mp + M)
          + (nw ? 0.00208 : 0.00209) * E2 * s(2 * M)
          - 0.00111 * s(Mp - 2 * F)
          - 0.00057 * s(Mp + 2 * F)
          + 0.00056 * E * s(2 * Mp + M)
          - 0.00042 * s(3 * Mp)
          + 0.00042 * E * s(M + 2 * F)
          + 0.00038 * E * s(M - 2 * F)
          - 0.00024 * E * s(2 * Mp - M)
          - 0.00017 * s(O)
          - 0.00007 * s(Mp + 2 * M)
          + 0.00004 * s(2 * Mp - 2 * F)
          + 0.00004 * s(3 * M)
          + 0.00003 * s(Mp + M - 2 * F)
          + 0.00003 * s(2 * Mp + 2 * F)
          - 0.00003 * s(Mp + M + 2 * F)
          + 0.00003 * s(Mp - M + 2 * F)
          - 0.00002 * s(Mp - M - 2 * F)
          - 0.00002 * s(3 * Mp + M)
          + 0.00002 * s(4 * Mp);
    } else {
        x = -0.62801 * s(Mp)
          + 0.17172 * E * s(M)
          - 0.01183 * E * s(Mp + M)
          + 0.00862 * s(2 * Mp)
          + 0.00804 * s(2 * F)
          + 0.00454 * E * s(Mp - M)
          + 0.00204 * E2 * s(2 * M)
          - 0.00180 * s(Mp - 2 * F)
          - 0.00070 * s(Mp + 2 * F)
          - 0.00040 * s(3 * Mp)
          - 0.00034 * E * s(2 * Mp - M)
          + 0.00032 * E * s(M + 2 * F)
          + 0.00032 * E * s(M - 2 * F)
          - 0.00028 * E2 * s(Mp + 2 * M)
          + 0.00027 * E * s(2 * Mp + M)
          - 0.00017 * s(O)
          - 0.00005 * s(Mp - M - 2 * F)
          + 0.00004 * s(2 * Mp + 2 * F)
          - 0.00004 * s(Mp + M + 2 * F)
          + 0.00004 * s(Mp - 2 * M)
          + 0.00003 * s(Mp + M - 2 * F)
          + 0.00003 * s(3 * M)
          + 0.00002 * s(2 * Mp - 2 * F)
          + 0.00002 * s(Mp - M + 2 * F)
          - 0.00002 * s(3 * Mp + M);
        var W = 0.00306 - 0.00038 * E * c(M) + 0.00026 * c(Mp) - 0.00002 * c(Mp - M) + 0.00002 * c(Mp + M) + 0.00002 * c(2 * F);
        x += q === 1 ? W : -W;
    }
    // The planetary arguments (each a minute or less).
    var A = [299.77 + 0.107408 * k - 0.009173 * T2, 251.88 + 0.016321 * k, 251.83 + 26.651886 * k,
             349.42 + 36.412478 * k, 84.66 + 18.206239 * k, 141.74 + 53.303771 * k, 207.14 + 2.453732 * k,
             154.84 + 7.306860 * k, 34.52 + 27.261239 * k, 207.19 + 0.121824 * k, 291.34 + 1.844379 * k,
             161.72 + 24.198154 * k, 239.56 + 25.513099 * k, 331.55 + 3.592518 * k];
    var AC = [0.000325, 0.000165, 0.000164, 0.000126, 0.000110, 0.000062, 0.000060,
              0.000056, 0.000047, 0.000042, 0.000040, 0.000037, 0.000035, 0.000023];
    for (var i = 0; i < 14; i++) x += AC[i] * s(_rad(A[i]));
    return jde + x;
}
// The same, as a Date (universal time).
function phaseDate(k) { return fromJD(phaseJDE(k) - DELTA_T); }

// The first phase of kind `q` (0 new, 0.25 first quarter, 0.5 full, 0.75 last)
// after `date` (strictly).
function next(date, q) {
    var jd = toJD(date) + DELTA_T;
    var k = Math.floor((jd - 2451550.09766) / SYNODIC) - 1 + q;
    for (var n = 0; n < 4; n++, k++) {
        var t = phaseJDE(k);
        if (t > jd) return fromJD(t - DELTA_T);
    }
    return fromJD(phaseJDE(k) - DELTA_T);
}
function nextNew(date) { return next(date, 0); }
function nextFull(date) { return next(date, 0.5); }

// The moon's elongation from the sun, 0..360° (0 new, 90 first quarter, 180
// full, 270 last quarter): 180° − the phase angle of Meeus (48.4), keeping the side.
function elongation(date) {
    var T = (toJD(date) + DELTA_T - 2451545) / 36525, T2 = T * T, T3 = T2 * T, T4 = T3 * T;
    var D = 297.8501921 + 445267.1114034 * T - 0.0018819 * T2 + T3 / 545868 - T4 / 113065000;
    var M = 357.5291092 + 35999.0502909 * T - 0.0001536 * T2 + T3 / 24490000;
    var Mp = 134.9633964 + 477198.8675055 * T + 0.0087414 * T2 + T3 / 69699 - T4 / 14712000;
    var s = function (d) { return Math.sin(_rad(d)); };
    return _norm(D + 6.289 * s(Mp) - 2.100 * s(M) + 1.274 * s(2 * D - Mp) + 0.658 * s(2 * D) + 0.214 * s(2 * Mp) + 0.110 * s(D));
}
// The lit fraction of the disc, 0..1.
function illumination(date) { return (1 - Math.cos(_rad(elongation(date)))) / 2; }

function _sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate(); }

var NAMES = { "new": "New moon", "waxing-crescent": "Waxing crescent", "first": "First quarter", "waxing-gibbous": "Waxing gibbous",
              "full": "Full moon", "waning-gibbous": "Waning gibbous", "last": "Last quarter", "waning-crescent": "Waning crescent" };

// Everything the widget shows: { elongation, fraction (0..1 through the
// month), illumination, waxing, phase (a NAMES key), name }. A principal phase
// is named all of the local day it falls on, as calendars do; between them, the
// crescent or gibbous moon of its side.
function info(date) {
    var e = elongation(date);
    var phase = e < 90 ? "waxing-crescent" : e < 180 ? "waxing-gibbous" : e < 270 ? "waning-gibbous" : "waning-crescent";
    // The principal phase nearest in time: the one the elongation is closest to.
    var q = Math.round(e / 90) % 4;
    var jd = toJD(date) + DELTA_T;
    var k = Math.round((jd - 2451550.09766) / SYNODIC - q / 4) + q / 4;
    var best = null, bestD = Infinity;
    for (var dk = -1; dk <= 1; dk++) {
        var t = phaseDate(k + dk), d = Math.abs(t.getTime() - date.getTime());
        if (d < bestD) { bestD = d; best = t; }
    }
    if (best && bestD < 2 * 86400000 && _sameDay(best, date)) phase = ["new", "first", "full", "last"][q];
    return { elongation: e, fraction: e / 360, illumination: (1 - Math.cos(_rad(e))) / 2,
             waxing: e < 180, phase: phase, name: NAMES[phase] };
}

// The terminator for drawing: the lit side (+1 right, −1 left, as seen from
// the north; `south` mirrors it) and the terminator's half-width as a share of
// the radius, signed: > 0 it bulges toward the lit limb (a crescent), < 0 away
// from it (gibbous). The lit part is the limb's half circle on `side` closed by
// the half ellipse through x = side · bulge · r.
function shape(elong, south) {
    var side = elong < 180 ? 1 : -1;
    return { side: south ? -side : side, bulge: Math.cos(_rad(elong)) };
}
