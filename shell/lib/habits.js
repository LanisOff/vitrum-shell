.pragma library
// Habits: the days each one was done, kept in the widget's options.
//   habits  ["Read", "Walk"]: the names, edited in the widget's options
//   marks   ["Read\t2026-10-24 2026-10-25", …]: the days per habit, in the
//           habits' order as last saved by the widget
// A habit renamed in place (the same position, a new name) keeps its days:
// a habit with no marks of its own takes those at its position when no
// current habit has that name any more. Days older than KEEP are dropped.

var KEEP = 400;

function pad(n) { return n < 10 ? "0" + n : String(n); }
function dayKey(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()); }
function addDays(d, n) { return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n); }

function _parse(mark) {
    var s = String(mark || ""), tab = s.indexOf("\t");
    var name = tab < 0 ? s : s.slice(0, tab);
    var days = tab < 0 ? [] : s.slice(tab + 1).split(" ").filter(function (x) { return /^\d{4}-\d{2}-\d{2}$/.test(x); });
    return { name: name, days: days };
}

// → [{ name, days: { "YYYY-MM-DD": true } }], one per habit (blank names left out).
function resolve(habits, marks) {
    var names = (habits || []).map(function (h) { return String(h).trim(); });
    var parsed = (marks || []).map(_parse);
    var byName = {}, i;
    for (i = 0; i < parsed.length; i++) if (!(parsed[i].name in byName)) byName[parsed[i].name] = parsed[i];
    var current = {};
    for (i = 0; i < names.length; i++) current[names[i]] = true;
    var out = [];
    for (i = 0; i < names.length; i++) {
        if (!names[i]) continue;
        var m = byName[names[i]];
        // Renamed: the old name at this position is no habit any more.
        if (!m && parsed[i] && !current[parsed[i].name]) m = parsed[i];
        var days = {};
        if (m) for (var k = 0; k < m.days.length; k++) days[m.days[k]] = true;
        out.push({ name: names[i], days: days });
    }
    return out;
}

// Resolved habits → the marks to save (days sorted, the old ones dropped).
function serialize(list, today) {
    var oldest = dayKey(addDays(today, -KEEP));
    return list.map(function (h) {
        var days = Object.keys(h.days).filter(function (d) { return h.days[d] && d >= oldest; }).sort();
        return h.name + "\t" + days.join(" ");
    });
}

// One day of one habit turned on or off → the new marks.
function toggle(habits, marks, index, key, today) {
    var list = resolve(habits, marks);
    if (index < 0 || index >= list.length) return serialize(list, today);
    var days = list[index].days;
    if (days[key]) delete days[key]; else days[key] = true;
    return serialize(list, today);
}

// The `n` days ending today, oldest first: [{ key, date, done }].
function week(days, today, n) {
    var out = [];
    for (var i = (n || 7) - 1; i >= 0; i--) {
        var d = addDays(today, -i), k = dayKey(d);
        out.push({ key: k, date: d, done: !!days[k] });
    }
    return out;
}

// Days in a row, up to today; a day not done yet today does not break it
// (the streak then counts to yesterday).
function streak(days, today) {
    var n = 0, d = days[dayKey(today)] ? today : addDays(today, -1);
    while (days[dayKey(d)] && n <= KEEP) { n++; d = addDays(d, -1); }
    return n;
}
