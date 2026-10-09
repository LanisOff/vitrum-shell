.pragma library
// Is it day? From sunrise/sunset when they are valid, else from a schedule
// of "HH:MM" strings (which may cross midnight).

function _valid(d) { return d instanceof Date && !isNaN(d.getTime()); }
function _min(hhmm) { var p = String(hhmm).split(":"); return (parseInt(p[0], 10) || 0) * 60 + (parseInt(p[1], 10) || 0); }

function isDay(now, sunrise, sunset, schedule) {
    var m = now.getHours() * 60 + now.getMinutes();
    if (_valid(sunrise) && _valid(sunset)) {
        var r = sunrise.getHours() * 60 + sunrise.getMinutes(), s = sunset.getHours() * 60 + sunset.getMinutes();
        return m >= r && m < s;
    }
    var sch = schedule || { light: "07:00", dark: "19:30" };
    var l = _min(sch.light), d = _min(sch.dark);
    return l < d ? (m >= l && m < d) : (m >= l || m < d);
}
