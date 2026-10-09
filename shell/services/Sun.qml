pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/sun.js" as SunLib
import "../lib/wallpaper.js" as WallLib

/*
 * Day or night, for the automatic light/dark scheme: sunrise and sunset from
 * Open-Meteo when the weather coordinates are set, otherwise the schedule in
 * settings. The result is also written to ~/.local/share/vitrum/scheme so
 * vitrum-theme picks the same scheme for niri.
 */
Singleton {
    id: root

    property date sunrise: new Date(NaN)
    property date sunset: new Date(NaN)
    property bool isDay: true

    readonly property real lat: Settings.get("weather.latitude", 0)
    readonly property real lon: Settings.get("weather.longitude", 0)

    function update() {
        isDay = SunLib.isDay(new Date(), sunrise, sunset,
                             { light: Settings.get("scheme.light", "07:00"), dark: Settings.get("scheme.dark", "19:30") });
    }

    // The flip: the state file for vitrum-theme, then everything outside the
    // shell re-themed (GTK, Qt, the terminal, niri), and the wallpaper's other
    // half when it has one (name-day.jpg / name-night.jpg).
    onIsDayChanged: {
        stateFile.setText(isDay ? "light\n" : "dark\n");
        if (Settings.get("scheme.mode", "auto") !== "auto") return;
        Settings.retheme();
        if (!Settings.get("wallpaper.dayNight", true)) return;
        const cur = Settings.get("wallpaper.path", "");
        const other = WallLib.counterpart(cur, isDay);
        if (other) { pairCheck.target = other; pairCheck.running = true; }
    }
    Process {
        id: pairCheck
        property string target: ""
        command: ["test", "-f", target.replace(/^~/, Quickshell.env("HOME"))]
        onExited: code => { if (code === 0) Wallpaper.set(target, "", null); }
    }
    onLatChanged: fetch.restart()
    onLonChanged: fetch.restart()

    Connections { target: Settings; function onChanged() { root.update(); } }

    Timer { interval: 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.update() }

    FileView { id: stateFile; path: Quickshell.env("HOME") + "/.local/share/vitrum/scheme"; blockLoading: true; blockWrites: true }

    // Sunrise/sunset once at start and every 6 hours.
    Timer { id: fetch; interval: 1000; running: true; repeat: false; onTriggered: { if (root.lat !== 0 || root.lon !== 0) req.running = true; again.restart(); } }
    Timer { id: again; interval: 6 * 3600 * 1000; onTriggered: fetch.restart() }
    Process {
        id: req
        // Second host as in Weather.qml: some ISPs drop api.open-meteo.com's address.
        readonly property string query: "/v1/forecast?latitude=" + root.lat + "&longitude=" + root.lon +
                                        "&daily=sunrise,sunset&timezone=auto&forecast_days=1"
        command: ["sh", "-c", ["api.open-meteo.com", "historical-forecast-api.open-meteo.com"]
                  .map(h => "curl -fsS --connect-timeout 4 --max-time 12 'https://" + h + query + "'").join(" || ")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text).daily;
                    root.sunrise = new Date(d.sunrise[0]);
                    root.sunset = new Date(d.sunset[0]);
                    root.update();
                } catch (e) { /* offline: the schedule stands */ }
            }
        }
    }
}
