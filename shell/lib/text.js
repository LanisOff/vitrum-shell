.pragma library
// Small text formatting helpers.

function elide(s, max) { s = String(s || ""); return s.length <= max ? s : s.slice(0, Math.max(0, max - 1)) + "…"; }

function formatBytes(n) {
    var units = ["B", "KiB", "MiB", "GiB", "TiB"], i = 0;
    while (n >= 1024 && i < units.length - 1) { n /= 1024; i++; }
    return (i === 0 ? String(n) : (Math.round(n * 10) / 10).toString()) + " " + units[i];
}

function formatPercent(x) { return Math.round(x * 100) + "%"; }

function _2(n) { return n < 10 ? "0" + n : String(n); }

function clockParts(d, h24) {
    var h = d.getHours(), ampm = "";
    if (!h24) { ampm = h >= 12 ? "PM" : "AM"; h = h % 12; if (h === 0) h = 12; }
    return { hh: _2(h), mm: _2(d.getMinutes()), ss: _2(d.getSeconds()), ampm: ampm };
}
