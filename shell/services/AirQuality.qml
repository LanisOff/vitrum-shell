pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "../lib/airquality.js" as Lib

/*
 * Air quality where the weather is: Open-Meteo's air-quality API, at the
 * Weather service's latitude and longitude (Settings → Time), and nothing
 * else leaves the machine. The European AQI, PM2.5 and PM10.
 *
 * Asked only while something shows it (subscribe / unsubscribe, in pairs),
 * every half hour (the data is hourly), and not while a game runs; when the
 * game ends it asks again only if the last answer is half an hour old.
 */
Singleton {
    id: root

    property int subscribers: 0
    function subscribe() { subscribers++; }
    function unsubscribe() { subscribers = Math.max(0, subscribers - 1); }

    readonly property bool located: Weather.located
    readonly property string request: Weather.latitude + "," + Weather.longitude
    readonly property bool wanted: subscribers > 0 && located && !GameMode.active
    readonly property int every: 30 * 60 * 1000

    property bool loading: false
    property string error: ""
    property var current: null          // { aqi, pm25, pm10, time }
    property string fetched: ""         // the place last asked about
    property real fetchedAt: 0
    property bool _again: false

    function refresh() {
        if (!located) return;
        if (fetch.running) { _again = true; return; }
        fetched = request;
        fetchedAt = Date.now();
        loading = true;
        fetch.command = ["curl", "-fsS", "--connect-timeout", "4", "--max-time", "12",
                         "https://air-quality-api.open-meteo.com" + Lib.query(Weather.latitude, Weather.longitude)];
        fetch.running = true;
    }
    Process {
        id: fetch
        stdout: StdioCollector {
            onStreamFinished: {
                const r = Lib.parse(text);
                if (r.error) { if (text.trim()) root.error = r.error; return; }
                root.current = r;
                root.error = "";
            }
        }
        onExited: code => {
            root.loading = false;
            if (code !== 0 && !root.current) root.error = "Could not reach the air-quality service";
            if (root._again) { root._again = false; if (root.request !== root.fetched) root.refresh(); }
        }
    }

    // Starts (and fires) whenever it is wanted again: a widget appears, a game ends.
    Timer {
        interval: root.every
        repeat: true
        running: root.wanted
        triggeredOnStart: true
        onTriggered: if (root.request !== root.fetched || Lib.stale(root.fetchedAt, Date.now(), root.every - 60000)) root.refresh()
    }
    // Another place: asked once the fields settle, and the old reading is not shown for it.
    onRequestChanged: { current = null; error = ""; if (wanted) settle.restart(); }
    Timer { id: settle; interval: 1500; onTriggered: if (root.wanted && root.request !== root.fetched) root.refresh() }
}
