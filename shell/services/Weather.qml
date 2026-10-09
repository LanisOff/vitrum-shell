pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

/*
 * Weather, from Open-Meteo.
 *
 * Off until you turn it on, because it is the only part of this desktop that
 * talks to the internet. Open-Meteo needs no account and no API key, and the
 * only thing that leaves the machine is a latitude and a longitude.
 *
 * Location comes from settings. Auto-detection is a second, separate opt-in:
 * it asks ipapi.co what your address looks like from outside, which is a
 * different disclosure and should be a different decision.
 */
Singleton {
    id: root

    readonly property bool enabled: latitude !== 0 || longitude !== 0
    readonly property real latitude: Settings.get("weather.latitude", 0)
    readonly property real longitude: Settings.get("weather.longitude", 0)
    readonly property string place: Settings.get("weather.place", "")
    readonly property bool metric: Settings.get("weather.units", "metric") === "metric"

    readonly property bool located: latitude !== 0 || longitude !== 0

    property bool loading: false
    property string error: ""
    property var current: null      // { temp, feels, code, humidity, wind, isDay }
    property var hourly: []         // [{ time, temp, code }]
    property var daily: []          // [{ date, code, max, min }]

    readonly property bool ready: current !== null

    // ------------------------------------------------------------- fetching --

    function refresh() {
        if (!enabled || !located) return;
        loading = true;
        error = "";
        // The same API on a second host: some ISPs (Russian ones among them)
        // drop the address api.open-meteo.com resolves to, and the request
        // just hangs. The connect timeout keeps that wait short.
        const query = "/v1/forecast" +
            "?latitude=" + latitude + "&longitude=" + longitude +
            "&current=temperature_2m,apparent_temperature,relative_humidity_2m," +
            "weather_code,wind_speed_10m,is_day" +
            "&hourly=temperature_2m,weather_code" +
            "&daily=weather_code,temperature_2m_max,temperature_2m_min" +
            "&forecast_days=7&timezone=auto" +
            "&temperature_unit=" + (metric ? "celsius" : "fahrenheit") +
            "&wind_speed_unit=" + (metric ? "kmh" : "mph");
        const get = host => "curl -fsS --connect-timeout 4 --max-time 12 'https://" + host + query + "'";
        fetch.command = ["sh", "-c", get("api.open-meteo.com") + " || " + get("historical-forecast-api.open-meteo.com")];
        fetch.running = true;
    }

    Process {
        id: fetch
        stdout: StdioCollector {
            onStreamFinished: root._parse(text)
        }
        onExited: code => {
            root.loading = false;
            if (code !== 0 && !root.ready) root.error = "Could not reach the weather service";
        }
    }

    function _parse(txt) {
        let j;
        try {
            j = JSON.parse(txt);
        } catch (e) {
            error = "Unexpected reply from the weather service";
            return;
        }
        if (j.error) { error = j.reason || "Weather request rejected"; return; }

        const c = j.current || {};
        current = {
            temp: Math.round(c.temperature_2m),
            feels: Math.round(c.apparent_temperature),
            code: c.weather_code,
            humidity: c.relative_humidity_2m,
            wind: Math.round(c.wind_speed_10m),
            isDay: c.is_day === 1
        };

        const h = j.hourly || {};
        const nowIso = (j.current && j.current.time) || "";
        const hours = [];
        if (h.time) {
            let start = h.time.indexOf(nowIso.substring(0, 13) + ":00");
            if (start < 0) start = 0;
            for (let i = start; i < Math.min(start + 12, h.time.length); i++) {
                hours.push({
                    time: h.time[i],
                    hour: h.time[i].substring(11, 16),
                    temp: Math.round(h.temperature_2m[i]),
                    code: h.weather_code[i]
                });
            }
        }
        hourly = hours;

        const d = j.daily || {};
        const days = [];
        if (d.time) {
            for (let i = 0; i < d.time.length; i++) {
                days.push({
                    date: d.time[i],
                    code: d.weather_code[i],
                    max: Math.round(d.temperature_2m_max[i]),
                    min: Math.round(d.temperature_2m_min[i])
                });
            }
        }
        daily = days;
        error = "";
    }

    Timer {
        interval: 900000              // fifteen minutes; the data is hourly
        running: root.enabled && root.located
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    onEnabledChanged: if (enabled) refresh()

    // --------------------------------------------------------- geolocation --

    property bool locating: false

    /// Separate opt-in: this asks a third party where your IP address is.
    function detectLocation() {
        locating = true;
        // ipapi.co's free tier runs out (HTTP 429); ipwho.is answers with the
        // same latitude/longitude/city, and "country" for "country_name".
        locate.command = ["sh", "-c",
            "curl -fsS --max-time 8 'https://ipapi.co/json/' || curl -fsS --max-time 8 'https://ipwho.is/'"];
        locate.running = true;
    }

    Process {
        id: locate
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    if (j.latitude !== undefined) {
                        Settings.set("weather.latitude", j.latitude);
                        Settings.set("weather.longitude", j.longitude);
                        Settings.set("weather.place",
                            [j.city, j.country_name || j.country].filter(s => s).join(", "));
                        root.refresh();
                    } else {
                        root.error = "Could not determine your location";
                    }
                } catch (e) {
                    root.error = "Could not determine your location";
                }
            }
        }
        onExited: root.locating = false
    }

    // ------------------------------------------------------------ WMO codes --
    //
    // Open-Meteo reports WMO weather codes. These are the buckets that matter
    // for choosing a glyph and a word.

    function describe(code) {
        const c = Number(code);
        if (c === 0) return "Clear";
        if (c === 1) return "Mainly clear";
        if (c === 2) return "Partly cloudy";
        if (c === 3) return "Overcast";
        if (c === 45 || c === 48) return "Fog";
        if (c >= 51 && c <= 57) return "Drizzle";
        if (c >= 61 && c <= 65) return "Rain";
        if (c === 66 || c === 67) return "Freezing rain";
        if (c >= 71 && c <= 77) return "Snow";
        if (c >= 80 && c <= 82) return "Showers";
        if (c === 85 || c === 86) return "Snow showers";
        if (c === 95) return "Thunderstorm";
        if (c >= 96) return "Thunderstorm with hail";
        return "—";
    }

    /// vitrum icon name (shell/data/icons.json) for a WMO code.
    function symbol(code, isDay) {
        const c = Number(code);
        const day = isDay === undefined ? true : isDay;
        if (c <= 1) return day ? "weather-clear" : "weather-night";
        if (c === 2) return "weather-partly";
        if (c === 3) return "weather-cloudy";
        if (c === 45 || c === 48) return "weather-fog";
        if ((c >= 51 && c <= 67) || (c >= 80 && c <= 82)) return "weather-rain";
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "weather-snow";
        if (c >= 95) return "weather-storm";
        return "weather-cloudy";
    }

    readonly property string unit: metric ? "°C" : "°F"
    readonly property string windUnit: metric ? "km/h" : "mph"
}
