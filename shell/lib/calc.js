.pragma library
// The launcher's calculator: a small recursive-descent parser — no eval, no
// Function(), only the operators and functions listed here.
//   expr   := term (('+'|'-') term)*
//   term   := unary (('*'|'/'|'%') unary)*
//   unary  := '-' unary | power
//   power  := atom ('^' unary)?
//   atom   := number | const | func '(' expr ')' | '(' expr ')'

var FUNCS = { sqrt: Math.sqrt, sin: Math.sin, cos: Math.cos, tan: Math.tan, asin: Math.asin, acos: Math.acos,
              atan: Math.atan, log: Math.log10, ln: Math.log, abs: Math.abs, round: Math.round,
              floor: Math.floor, ceil: Math.ceil, exp: Math.exp };
var CONSTS = { pi: Math.PI, e: Math.E };

function _tokens(s) {
    var out = [], i = 0;
    s = String(s).replace(/(\d),(\d)/g, "$1.$2");
    while (i < s.length) {
        var ch = s[i];
        if (/\s/.test(ch)) { i++; continue; }
        var m = /^(\d+\.?\d*|\.\d+)(e[+-]?\d+)?/i.exec(s.slice(i));
        if (m) { out.push({ t: "n", v: parseFloat(m[0]) }); i += m[0].length; continue; }
        m = /^[a-z]+/i.exec(s.slice(i));
        if (m) { out.push({ t: "id", v: m[0].toLowerCase() }); i += m[0].length; continue; }
        if ("+-*/%^()".indexOf(ch) >= 0) { out.push({ t: ch }); i++; continue; }
        if (ch === "×") { out.push({ t: "*" }); i++; continue; }
        if (ch === "÷") { out.push({ t: "/" }); i++; continue; }
        return null;
    }
    return out;
}

function evaluate(src) {
    var toks = _tokens(src);
    if (!toks || toks.length === 0) return null;
    var p = 0;
    function peek() { return toks[p] ? toks[p].t : null; }
    function expr() {
        var v = term();
        while (peek() === "+" || peek() === "-") { var op = toks[p++].t; var r = term(); v = op === "+" ? v + r : v - r; }
        return v;
    }
    function term() {
        var v = unary();
        while (peek() === "*" || peek() === "/" || peek() === "%") {
            var op = toks[p++].t, r = unary();
            v = op === "*" ? v * r : op === "/" ? v / r : v % r;
        }
        return v;
    }
    function unary() { if (peek() === "-") { p++; return -unary(); } if (peek() === "+") { p++; return unary(); } return power(); }
    function power() { var b = atom(); if (peek() === "^") { p++; return Math.pow(b, unary()); } return b; }
    function atom() {
        var tk = toks[p++];
        if (!tk) throw "end";
        if (tk.t === "n") return tk.v;
        if (tk.t === "(") { var v = expr(); if (peek() !== ")") throw "paren"; p++; return v; }
        if (tk.t === "id") {
            if (CONSTS.hasOwnProperty(tk.v)) return CONSTS[tk.v];
            if (FUNCS.hasOwnProperty(tk.v) && peek() === "(") { p++; var a = expr(); if (peek() !== ")") throw "paren"; p++; return FUNCS[tk.v](a); }
        }
        throw "token";
    }
    try {
        var v = expr();
        if (p !== toks.length || typeof v !== "number" || !isFinite(v)) return null;
        return v;
    } catch (e) { return null; }
}

// Worth showing as a calculation: an operator or a function, and it evaluates.
function looksLikeMath(s) {
    return /[0-9)]\s*[-+*/%^×÷]|\b(sqrt|sin|cos|tan|log|ln|abs|pi)\b/i.test(String(s)) && evaluate(s) !== null;
}

// "5 km to mi", "100 c in f", "1 gib to mb"
var UNITS = {
    length: { m: 1, km: 1000, cm: 0.01, mm: 0.001, mi: 1609.344, ft: 0.3048, "in": 0.0254, yd: 0.9144 },
    mass:   { kg: 1, g: 0.001, mg: 1e-6, lb: 0.45359237, oz: 0.028349523125, t: 1000 },
    data:   { b: 1, kb: 1e3, mb: 1e6, gb: 1e9, tb: 1e12, kib: 1024, mib: 1048576, gib: 1073741824, tib: 1099511627776 },
    time:   { s: 1, min: 60, h: 3600, d: 86400 },
    speed:  { kmh: 1, mph: 1.609344, ms: 3.6 }
};
function convert(q) {
    var m = /^\s*(-?[\d.,]+)\s*([a-z°]+)\s+(?:to|in)\s+([a-z°]+)\s*$/i.exec(String(q));
    if (!m) return null;
    var v = parseFloat(m[1].replace(",", ".")), a = m[2].toLowerCase().replace("°", ""), b = m[3].toLowerCase().replace("°", "");
    var temp = { c: 1, f: 1, k: 1 };
    if (temp[a] && temp[b]) {
        var c = a === "c" ? v : a === "f" ? (v - 32) * 5 / 9 : v - 273.15;
        return b === "c" ? c : b === "f" ? c * 9 / 5 + 32 : c + 273.15;
    }
    for (var k in UNITS) {
        var u = UNITS[k];
        if (u.hasOwnProperty(a) && u.hasOwnProperty(b)) return v * u[a] / u[b];
    }
    return null;
}

// Money: "10 usd to rub", "10 $ in ₽". rates: currency code → units per USD.
var SYMBOLS = { "$": "USD", "€": "EUR", "₽": "RUB", "£": "GBP", "¥": "JPY", "₴": "UAH", "₸": "KZT", "₺": "TRY" };
var CURRENCY = /^\s*(-?[\d.,]+)\s*([a-z]{3}|[$€₽£¥₴₸₺])\s+(?:to|in)\s+([a-z]{3}|[$€₽£¥₴₸₺])\s*$/i;
function _code(s) { return SYMBOLS[s] || String(s).toUpperCase(); }
function isCurrencyQuery(q) {
    var m = CURRENCY.exec(String(q));
    if (!m) return false;
    var known = /^(usd|eur|rub|gbp|jpy|cny|uah|kzt|try|chf|pln|czk|byn|aud|cad|inr|krw|sek|nok|gel|amd)$/i;
    return (SYMBOLS[m[2]] || known.test(m[2])) && (SYMBOLS[m[3]] || known.test(m[3]));
}
function convertCurrency(q, rates) {
    if (!rates) return null;
    var m = CURRENCY.exec(String(q));
    if (!m) return null;
    var a = rates[_code(m[2])], b = rates[_code(m[3])];
    if (!a || !b) return null;
    return parseFloat(m[1].replace(",", ".")) / a * b;
}
