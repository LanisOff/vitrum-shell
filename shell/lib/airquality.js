.pragma library
// Air quality from Open-Meteo's air-quality API: the European AQI and the
// two particle sizes, and what a number means (good → extremely poor).

// The bands' upper ends, as Open-Meteo documents them; past the last is the sixth level.
var BANDS = {
    aqi:   [20, 40, 60, 80, 100],
    pm2_5: [10, 20, 25, 50, 75],
    pm10:  [20, 40, 50, 100, 150]
};
var LEVELS = ["Good", "Fair", "Moderate", "Poor", "Very poor", "Extremely poor"];
// A hue per level for Colors.meaning: green, yellow-green, yellow, orange, red, purple.
var HUES = [0.36, 0.24, 0.14, 0.07, 0.0, 0.85];

/// 0 (good) … 5 (extremely poor); -1 when there is no reading.
function level(value, kind) {
    var v = Number(value), b = BANDS[kind || "aqi"] || BANDS.aqi;
    if (value === null || value === undefined || value === "" || !isFinite(v) || v < 0) return -1;
    for (var i = 0; i < b.length; i++) if (v <= b[i]) return i;
    return b.length;
}
function label(lv) { return lv >= 0 && lv < LEVELS.length ? LEVELS[lv] : "—"; }
function hue(lv) { return lv >= 0 && lv < HUES.length ? HUES[lv] : 0.36; }
/// Where a reading sits on its scale, for a ring or a bar: the top of the
/// "very poor" band is full.
function fraction(value, kind) {
    var v = Number(value), b = BANDS[kind || "aqi"] || BANDS.aqi;
    return isFinite(v) && v > 0 ? Math.min(1, v / b[b.length - 1]) : 0;
}

/// The request's path and query.
function query(lat, lon) {
    return "/v1/air-quality?latitude=" + lat + "&longitude=" + lon +
           "&current=european_aqi,pm2_5,pm10&timezone=auto";
}

/// The reply → { aqi, pm25, pm10, time } or { error }.
function parse(text) {
    var j;
    try { j = JSON.parse(String(text || "")); } catch (e) { return { error: "Unexpected reply from the air-quality service" }; }
    if (!j || typeof j !== "object") return { error: "Unexpected reply from the air-quality service" };
    if (j.error) return { error: String(j.reason || "Air-quality request rejected") };
    var c = j.current || {};
    function num(v) { return typeof v === "number" && isFinite(v) ? v : null; }
    var out = { aqi: num(c.european_aqi), pm25: num(c.pm2_5), pm10: num(c.pm10), time: String(c.time || "") };
    if (out.aqi === null && out.pm25 === null && out.pm10 === null) return { error: "No air-quality data for this place" };
    return out;
}

/// Asked longer ago than `maxAge` ms (or never).
function stale(fetchedAt, now, maxAge) { return !fetchedAt || now - fetchedAt >= maxAge; }
