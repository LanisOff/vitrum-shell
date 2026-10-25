.pragma library
// The agenda: local iCalendar files (.ics) read into events, and the events of
// the next days expanded from them, repeats included.
//
// A calendar is one .ics file, or a folder of them (vdirsyncer's layout: one
// event a file, its colour and name in the files `color` and `displayname`).
// Read: VEVENT (SUMMARY, LOCATION, DTSTART, DTEND or DURATION, STATUS, UID,
// RECURRENCE-ID, EXDATE, RRULE: DAILY, WEEKLY, MONTHLY, YEARLY with INTERVAL,
// COUNT, UNTIL, BYDAY, BYMONTHDAY, BYMONTH), VTIMEZONE (STANDARD/DAYLIGHT
// with a yearly BYMONTH + BYDAY rule), X-WR-CALNAME, COLOR, X-APPLE-CALENDAR-COLOR.
// A time with a TZID that has no VTIMEZONE is read as local time.

var DAY = 86400000;
var WEEKDAYS = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];

// ---------------------------------------------------------------- reading ---

// The reader's dump (see AgendaWidget): "\x1eCAL <path>" starts a calendar,
// "\x1eMETA color|name <value>" sets its colour or name, "\x1eSIG <sig>" is the
// folder's signature; the rest is iCalendar text. → { sig, calendars: [{ id, color, name, text }] }
function splitDump(text) {
    var out = { sig: "", calendars: [] }, cur = null, body = [];
    var lines = String(text || "").split("\n");
    function flush() { if (cur) { cur.text = body.join("\n"); out.calendars.push(cur); } body = []; }
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i];
        if (l.charAt(0) === "\x1e") {
            var m = l.slice(1).match(/^(\w+) ?(.*)$/);
            if (!m) continue;
            if (m[1] === "SIG") out.sig = m[2];
            else if (m[1] === "CAL") { flush(); cur = { id: m[2], color: "", name: "", text: "" }; }
            else if (m[1] === "META" && cur) {
                var mm = m[2].match(/^(color|name) (.*)$/);
                if (mm) cur[mm[1]] = mm[2].trim();
            }
        } else if (cur) body.push(l);
    }
    flush();
    return out;
}

// Content lines, unfolded (a line starting with a space or tab continues the last).
function _unfold(text) {
    var raw = String(text || "").replace(/\r\n?/g, "\n").split("\n"), out = [];
    for (var i = 0; i < raw.length; i++) {
        var l = raw[i];
        if ((l.charAt(0) === " " || l.charAt(0) === "\t") && out.length) out[out.length - 1] += l.slice(1);
        else if (l.length) out.push(l);
    }
    return out;
}
// "NAME;P=V;Q=\"a:b\":value" → { name, params: { P: V }, value }
function parseLine(line) {
    var i = 0, q = false;
    for (; i < line.length; i++) {
        var c = line.charAt(i);
        if (c === '"') q = !q;
        else if (c === ":" && !q) break;
    }
    var head = line.slice(0, i), value = line.slice(i + 1);
    var parts = head.split(";"), params = {};
    for (var j = 1; j < parts.length; j++) {
        var eqAt = parts[j].indexOf("=");
        if (eqAt > 0) params[parts[j].slice(0, eqAt).toUpperCase()] = parts[j].slice(eqAt + 1).replace(/^"|"$/g, "");
    }
    return { name: parts[0].toUpperCase(), params: params, value: value };
}
function unescapeText(v) {
    return String(v).replace(/\\([\\;,nN])/g, function (_, c) { return c === "n" || c === "N" ? "\n" : c; });
}

// A date or date-time value → { y, mo (0-based), d, h, mi, s, date (no time), utc, tzid }.
function parseDateValue(value, params) {
    var m = String(value || "").trim().match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$/);
    if (!m) return null;
    var isDate = m[4] === undefined || (params && params.VALUE === "DATE");
    return { y: +m[1], mo: +m[2] - 1, d: +m[3], h: isDate ? 0 : +m[4], mi: isDate ? 0 : +m[5], s: isDate ? 0 : +(m[6] || 0),
             date: isDate, utc: !isDate && m[7] === "Z", tzid: !isDate && m[7] !== "Z" && params && params.TZID ? params.TZID : "" };
}
// "P1DT2H", "-PT15M", "P2W" → milliseconds.
function parseDuration(v) {
    var m = String(v || "").trim().match(/^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/);
    if (!m) return 0;
    var ms = ((+(m[2] || 0) * 7 + +(m[3] || 0)) * 24 * 3600 + +(m[4] || 0) * 3600 + +(m[5] || 0) * 60 + +(m[6] || 0)) * 1000;
    return m[1] === "-" ? -ms : ms;
}
function parseRule(v) {
    var r = {}, parts = String(v || "").split(";");
    for (var i = 0; i < parts.length; i++) {
        var kv = parts[i].split("=");
        if (kv.length === 2) r[kv[0].toUpperCase()] = kv[1];
    }
    if (!r.FREQ) return null;
    var out = { freq: r.FREQ.toUpperCase(), interval: Math.max(1, parseInt(r.INTERVAL, 10) || 1),
                count: r.COUNT ? parseInt(r.COUNT, 10) : 0, until: r.UNTIL ? parseDateValue(r.UNTIL, {}) : null,
                byday: [], bymonthday: [], bymonth: [] };
    if (r.BYDAY) out.byday = r.BYDAY.split(",").map(function (s) {
        var m = s.trim().toUpperCase().match(/^([+-]?\d{1,2})?(SU|MO|TU|WE|TH|FR|SA)$/);
        return m ? { n: m[1] ? parseInt(m[1], 10) : 0, wd: WEEKDAYS.indexOf(m[2]) } : null;
    }).filter(function (x) { return x; });
    if (r.BYMONTHDAY) out.bymonthday = r.BYMONTHDAY.split(",").map(function (s) { return parseInt(s, 10); }).filter(function (n) { return n && Math.abs(n) <= 31; });
    if (r.BYMONTH) out.bymonth = r.BYMONTH.split(",").map(function (s) { return parseInt(s, 10) - 1; }).filter(function (n) { return n >= 0 && n < 12; });
    return out;
}

// --------------------------------------------------------------- time zones ---

function _offsetMin(v) {
    var m = String(v || "").trim().match(/^([+-])(\d{2})(\d{2})/);
    return m ? (m[1] === "-" ? -1 : 1) * (+m[2] * 60 + +m[3]) : 0;
}
// The day of the month of the n-th weekday wd of a month (n < 0: from its end).
function nthWeekday(y, mo, wd, n) {
    if (n > 0) {
        var first = new Date(Date.UTC(y, mo, 1)).getUTCDay();
        var d = 1 + (wd - first + 7) % 7 + (n - 1) * 7;
        return d <= _daysIn(y, mo) ? d : 0;
    }
    var len = _daysIn(y, mo), last = new Date(Date.UTC(y, mo, len)).getUTCDay();
    var dl = len - (last - wd + 7) % 7 + (n + 1) * 7;
    return dl >= 1 ? dl : 0;
}
function _daysIn(y, mo) { return new Date(Date.UTC(y, mo + 1, 0)).getUTCDate(); }

// A zone is a VTIMEZONE's observances: [{ start (fields), to, from (minutes east of UTC), rule }].
// → its UTC offset in minutes at the wall time `f`; null for no zone.
function tzOffset(zone, f) {
    if (!zone || !zone.length) return null;
    var wall = Date.UTC(f.y, f.mo, f.d, f.h, f.mi, f.s), best = null, bestAt = -Infinity;
    function consider(o, t) { if (t !== null && t <= wall && t > bestAt) { bestAt = t; best = o; } }
    for (var i = 0; i < zone.length; i++) {
        var o = zone[i], s = o.start, r = o.rule;
        var first = Date.UTC(s.y, s.mo, s.d, s.h, s.mi, s.s);
        if (!r || !r.bymonth.length || !r.byday.length) { consider(o, first); continue; }
        // A yearly rule: its transitions this year and last (wall time), none before its start.
        for (var y = f.y; y >= f.y - 1; y--) {
            var dd = nthWeekday(y, r.bymonth[0], r.byday[0].wd, r.byday[0].n || 1);
            var t = dd ? Date.UTC(y, r.bymonth[0], dd, s.h, s.mi, s.s) : null;
            consider(o, t !== null && t >= first ? t : null);
        }
    }
    // Before every recorded transition: what the first one changed from.
    return best ? best.to : zone[0].from;
}
// Fields of a date or date-time → a real instant (ms).
function instant(f, zones) {
    if (f.date) return new Date(f.y, f.mo, f.d).getTime();
    if (f.utc) return Date.UTC(f.y, f.mo, f.d, f.h, f.mi, f.s);
    var off = f.tzid ? tzOffset(zones && zones[f.tzid], f) : null;
    if (off === null || off === undefined) return new Date(f.y, f.mo, f.d, f.h, f.mi, f.s).getTime();
    return Date.UTC(f.y, f.mo, f.d, f.h, f.mi, f.s) - off * 60000;
}

// ----------------------------------------------------------------- parsing ---

// One calendar's text → { name, color, events: [{ uid, title, location, start (fields),
// end (fields | null), duration (ms), allDay, rule, exdates: [ms], recurrenceId (fields | null) }], zones }
function parseCalendar(text) {
    var lines = _unfold(text);
    var cal = { name: "", color: "", events: [], zones: {} };
    var stack = [], ev = null, tz = null, obs = null;
    for (var i = 0; i < lines.length; i++) {
        var p = parseLine(lines[i]);
        if (p.name === "BEGIN") {
            var what = p.value.toUpperCase();
            stack.push(what);
            if (what === "VEVENT") ev = { uid: "", title: "", location: "", start: null, end: null, duration: 0, rule: null, exdates: [], recurrenceId: null, cancelled: false };
            else if (what === "VTIMEZONE") tz = { id: "", obs: [] };
            else if ((what === "STANDARD" || what === "DAYLIGHT") && tz) obs = { start: null, to: 0, from: 0, rule: null };
            continue;
        }
        if (p.name === "END") {
            var done = stack.pop();
            if (done === "VEVENT" && ev) {
                if (ev.start && !ev.cancelled) {
                    ev.allDay = ev.start.date;
                    cal.events.push(ev);
                }
                ev = null;
            } else if (done === "VTIMEZONE" && tz) {
                if (tz.id) cal.zones[tz.id] = tz.obs;
                tz = null;
            } else if ((done === "STANDARD" || done === "DAYLIGHT") && obs && tz) {
                if (obs.start) tz.obs.push(obs);
                obs = null;
            }
            continue;
        }
        var top = stack[stack.length - 1];
        if (top === "VEVENT" && ev) {
            switch (p.name) {
            case "UID": ev.uid = p.value; break;
            case "SUMMARY": ev.title = unescapeText(p.value); break;
            case "LOCATION": ev.location = unescapeText(p.value); break;
            case "DTSTART": ev.start = parseDateValue(p.value, p.params); break;
            case "DTEND": ev.end = parseDateValue(p.value, p.params); break;
            case "DURATION": ev.duration = parseDuration(p.value); break;
            case "RRULE": ev.rule = parseRule(p.value); break;
            case "RECURRENCE-ID": ev.recurrenceId = parseDateValue(p.value, p.params); break;
            case "STATUS": ev.cancelled = p.value.toUpperCase() === "CANCELLED"; break;
            case "EXDATE":
                p.value.split(",").forEach(function (v) { var f = parseDateValue(v, p.params); if (f) ev.exdates.push(f); });
                break;
            }
        } else if (top === "VTIMEZONE" && tz && p.name === "TZID") tz.id = p.value;
        else if ((top === "STANDARD" || top === "DAYLIGHT") && obs) {
            if (p.name === "DTSTART") obs.start = parseDateValue(p.value, {});
            else if (p.name === "TZOFFSETTO") obs.to = _offsetMin(p.value);
            else if (p.name === "TZOFFSETFROM") obs.from = _offsetMin(p.value);
            else if (p.name === "RRULE") obs.rule = parseRule(p.value);
        } else if (top === "VCALENDAR") {
            if (p.name === "X-WR-CALNAME" && !cal.name) cal.name = unescapeText(p.value);
            else if ((p.name === "COLOR" || p.name === "X-APPLE-CALENDAR-COLOR") && !cal.color) cal.color = p.value.trim();
        }
    }
    return cal;
}

// ------------------------------------------------------------- repeating ---

function _addDays(f, n) {
    var d = new Date(Date.UTC(f.y, f.mo, f.d + n));
    return { y: d.getUTCFullYear(), mo: d.getUTCMonth(), d: d.getUTCDate(), h: f.h, mi: f.mi, s: f.s, date: f.date, utc: f.utc, tzid: f.tzid };
}
function _withDay(f, y, mo, d) { return { y: y, mo: mo, d: d, h: f.h, mi: f.mi, s: f.s, date: f.date, utc: f.utc, tzid: f.tzid }; }
function _wd(f) { return new Date(Date.UTC(f.y, f.mo, f.d)).getUTCDay(); }
function _dayNum(f) { return Math.round(Date.UTC(f.y, f.mo, f.d) / DAY); }

// The days of a month a rule picks (sorted), from BYMONTHDAY, else BYDAY, else `dflt`.
function _monthDays(rule, y, mo, dflt) {
    var len = _daysIn(y, mo), out = [], i;
    if (rule.bymonthday.length) {
        for (i = 0; i < rule.bymonthday.length; i++) {
            var n = rule.bymonthday[i], d = n > 0 ? n : len + n + 1;
            if (d >= 1 && d <= len) out.push(d);
        }
    } else if (rule.byday.length) {
        for (i = 0; i < rule.byday.length; i++) {
            var b = rule.byday[i];
            if (b.n) { var dd = nthWeekday(y, mo, b.wd, b.n); if (dd) out.push(dd); }
            else for (var x = 1; x <= len; x++) if (new Date(Date.UTC(y, mo, x)).getUTCDay() === b.wd) out.push(x);
        }
    } else if (dflt <= len) out.push(dflt);
    return out.sort(function (a, b) { return a - b; }).filter(function (v, k, a) { return k === 0 || a[k - 1] !== v; });
}

// The starts (fields) of a repeating event up to `toMs`, from its first. On a
// rule with no COUNT the periods well before `fromMs` are skipped (a daily one
// from 2010 is not walked from 2010); a guard bounds the rest.
function expand(ev, fromMs, toMs, zones) {
    var r = ev.rule, s = ev.start, out = [];
    if (!r) return [s];
    var startMs = instant(s, zones);
    // UNTIL is inclusive; a date alone means the end of that day.
    var untilMs = !r.until ? Infinity : r.until.date ? new Date(r.until.y, r.until.mo, r.until.d, 23, 59, 59).getTime() : instant(r.until, zones);
    var count = 0, guard = 0, period = 0;
    var span = Math.max(0, fromMs - startMs);
    function take(f) {
        var t = instant(f, zones);
        if (t < startMs) return true;
        if (t > untilMs || t >= toMs) return false;
        count++;
        if (r.count && count > r.count) return false;
        out.push(f);
        return true;
    }
    var i, go = true;
    if (r.freq === "DAILY") {
        if (!r.count) period = Math.max(0, Math.floor(span / DAY / r.interval) - 1);
        for (; go && guard < 4000; period++, guard++) {
            var f = _addDays(s, period * r.interval);
            if (r.byday.length && !r.byday.some(function (b) { return b.wd === _wd(f); })) { if (instant(f, zones) >= toMs) break; continue; }
            if (r.bymonth.length && r.bymonth.indexOf(f.mo) < 0) { if (instant(f, zones) >= toMs) break; continue; }
            go = take(f);
        }
    } else if (r.freq === "WEEKLY") {
        var wds = r.byday.length ? r.byday.map(function (b) { return b.wd; }) : [_wd(s)];
        // Weeks from Monday (WKST=MO): days from the start week's Monday, in order.
        var off = wds.map(function (w) { return (w + 6) % 7; }).sort(function (a, b) { return a - b; });
        var monday = _addDays(s, -((_wd(s) + 6) % 7));
        if (!r.count) period = Math.max(0, Math.floor(span / (7 * DAY) / r.interval) - 1);
        for (; go && guard < 3000; period++, guard++) {
            for (i = 0; go && i < off.length; i++) go = take(_addDays(monday, period * 7 * r.interval + off[i]));
        }
    } else if (r.freq === "MONTHLY") {
        for (; go && guard < 1200; period++, guard++) {
            var mAll = s.mo + period * r.interval, y = s.y + Math.floor(mAll / 12), mo = ((mAll % 12) + 12) % 12;
            if (r.bymonth.length && r.bymonth.indexOf(mo) < 0) continue;
            var days = _monthDays(r, y, mo, s.d);
            for (i = 0; go && i < days.length; i++) go = take(_withDay(s, y, mo, days[i]));
            if (Date.UTC(y, mo, 1) > toMs + 31 * DAY) break;
        }
    } else if (r.freq === "YEARLY") {
        var months = r.bymonth.length ? r.bymonth.slice().sort(function (a, b) { return a - b; }) : [s.mo];
        for (; go && guard < 300; period++, guard++) {
            var yy = s.y + period * r.interval;
            for (var k = 0; go && k < months.length; k++) {
                var ds = _monthDays(r, yy, months[k], s.d);
                for (i = 0; go && i < ds.length; i++) go = take(_withDay(s, yy, months[k], ds[i]));
            }
            if (Date.UTC(yy, 0, 1) > toMs) break;
        }
    } else out.push(s);
    return out;
}

// --------------------------------------------------------------- the agenda ---

// Calendars ([{ id, color, name, text }] as splitDump gives) → parsed, once
// per read: [{ id, name, color, hue, events, zones }]. `hue` is a stable hue
// (degrees) for a calendar with no colour of its own.
function parseAll(dumped) {
    return (dumped || []).map(function (c, i) {
        var p = parseCalendar(c.text);
        var base = String(c.id || "").replace(/\/+$/, "").split("/").pop().replace(/\.ics$/i, "");
        var h = 0, key = c.id || String(i);
        for (var j = 0; j < key.length; j++) h = (h * 31 + key.charCodeAt(j)) % 360;
        var color = String(c.color || p.color || "");
        // #rrggbbaa (Apple's form) → #rrggbb: QML would read it as #aarrggbb.
        if (/^#[0-9a-fA-F]{8}$/.test(color)) color = color.slice(0, 7);
        return { id: c.id, name: c.name || p.name || base || "Calendar", color: color, hue: h, events: p.events, zones: p.zones };
    });
}

// The occurrences between fromMs and toMs, sorted by start:
// [{ title, location, start (ms), end (ms), allDay, cal (index) }].
function occurrences(cals, fromMs, toMs) {
    var out = [];
    for (var c = 0; c < (cals || []).length; c++) {
        var cal = cals[c], evs = cal.events, zones = cal.zones;
        // Moved or edited single occurrences (RECURRENCE-ID): by uid, the instants they replace.
        var moved = {};
        for (var i = 0; i < evs.length; i++) if (evs[i].recurrenceId) {
            var key = evs[i].uid;
            (moved[key] = moved[key] || {})[instant(evs[i].recurrenceId, zones)] = true;
        }
        for (i = 0; i < evs.length; i++) {
            var ev = evs[i];
            var s0 = instant(ev.start, zones);
            var len = ev.end ? instant(ev.end, zones) - s0 : ev.duration ? ev.duration : ev.allDay ? DAY : 0;
            if (len < 0) len = 0;
            var ex = {};
            for (var x = 0; x < ev.exdates.length; x++) ex[instant(ev.exdates[x], zones)] = true;
            var starts = ev.recurrenceId ? [ev.start] : expand(ev, fromMs - Math.max(len, DAY), toMs, zones);
            for (var k = 0; k < starts.length; k++) {
                var f = starts[k], st = instant(f, zones);
                if (ex[st] || (!ev.recurrenceId && ev.rule && moved[ev.uid] && moved[ev.uid][st])) continue;
                // An all-day event keeps its length in days (over a clock change too).
                var en = ev.allDay ? instant(_addDays(f, Math.max(1, Math.round(len / DAY))), zones) : st + len;
                if (en <= fromMs && !(en === st && st >= fromMs) || st >= toMs) continue;
                out.push({ title: ev.title || "(untitled)", location: ev.location, start: st, end: en, allDay: ev.allDay, cal: c });
            }
        }
    }
    out.sort(function (a, b) { return a.start - b.start || (b.allDay ? 1 : 0) - (a.allDay ? 1 : 0) || (a.title < b.title ? -1 : 1); });
    return out;
}

function _dayStart(ms) { var d = new Date(ms); return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime(); }
function _nextDay(ms) { var d = new Date(ms); return new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1).getTime(); }

// The agenda the widget shows: `days` local days from `nowMs`'s, each
// { start (ms), items: [{ title, location, cal, allDay, kind, at }] } where kind
// is "allday", "start" (at = its start), "until" (begun before; at = its end) or
// "through" (a timed one that covers the whole day). Finished ones are left out
// (end ≤ now), and all-day ones when allDay is false. Days with nothing are kept.
function agenda(occ, nowMs, days, allDay) {
    var out = [], d0 = _dayStart(nowMs);
    for (var n = 0, ds = d0; n < Math.max(1, days); n++) {
        var de = _nextDay(ds), items = [];
        for (var i = 0; i < occ.length; i++) {
            var o = occ[i];
            if (o.allDay && allDay === false) continue;
            if (o.end <= nowMs && !(o.end === o.start && o.start >= nowMs)) continue;
            var inDay = o.start < de && (o.end > ds || (o.end === o.start && o.start >= ds));
            if (!inDay) continue;
            var kind = o.allDay ? "allday" : o.start >= ds ? "start" : o.end < de ? "until" : "through";
            items.push({ title: o.title, location: o.location, cal: o.cal, allDay: o.allDay, kind: kind,
                         at: kind === "start" ? o.start : kind === "until" ? o.end : 0, start: o.start, end: o.end });
        }
        out.push({ start: ds, items: items });
        ds = de;
    }
    return out;
}
