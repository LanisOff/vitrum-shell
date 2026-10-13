import QtQuick
import qs.services
import qs.theme
import qs.components

/*
 * The weather where you are (Weather; the place is set in Settings → Time).
 *   S   the symbol and the temperature, what it is like under them
 *   M   the header; now (symbol, temperature, what it is like, feels like);
 *       the next hours along the bottom
 *   L   as M, with wind and humidity as chips, and the next days
 * options: hours (hours ahead shown, 0 hides them), details (feels like, wind, humidity).
 * In a gallery card with no weather yet, a sample day stands in.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    readonly property bool sample: preview && !Weather.ready
    readonly property bool ready: Weather.ready || sample
    readonly property var now: sample ? { temp: 18, feels: 17, code: 2, humidity: 64, wind: 12, isDay: true } : Weather.current
    readonly property var hours: sample ? [19, 20, 21, 22, 23, 0, 1, 2].map((h, i) => ({ time: new Date(2026, 0, 1, h).getTime(), temp: 18 - i * 0.7, code: i < 3 ? 2 : 3 }))
                                        : Weather.hourly.slice(1)
    readonly property var days: sample ? [0, 1, 2, 3].map(i => ({ date: new Date(2026, 0, 2 + i).getTime(), code: [2, 61, 3, 0][i], max: 19 - i, min: 9 + i % 2 }))
                                       : Weather.daily.slice(1, 5)
    readonly property string sym: ready ? Weather.symbol(now.code, now.isDay) : "weather-clear"
    readonly property int hoursShown: Math.max(0, Math.min(8, options.hours !== undefined ? options.hours : 5))

    WidgetHeader {
        id: head
        visible: root.sizeClass !== "S"
        height: visible ? implicitHeight : 0
        icon: "weather-partly"; title: "Weather"
        trailing: root.sample ? "Riga" : (Weather.place || "").split(",")[0]
    }
    WidgetEmpty {
        visible: !root.ready
        icon: "weather-cloudy"
        text: !Weather.located ? "Set a location in Settings → Time" : Weather.error ? Weather.error : "Loading…"
    }

    // ---- S: one glance.
    Column {
        visible: root.ready && root.sizeClass === "S"
        anchors.centerIn: parent
        spacing: 2
        WeatherGlyph { anchors.horizontalCenter: parent.horizontalCenter; kind: root.sym; day: root.now ? root.now.isDay : true; size: root.height * 0.36 }
        Label { anchors.horizontalCenter: parent.horizontalCenter; text: root.ready ? Math.round(root.now.temp) + "°" : ""; numeric: true; size: Math.round(root.height * 0.26); font.weight: Font.Light }
        Label { anchors.horizontalCenter: parent.horizontalCenter; width: root.width; horizontalAlignment: Text.AlignHCenter
                text: root.ready ? Weather.describe(root.now.code) : ""; role: "dim"; size: Tokens.textSmall }
    }

    // ---- M and L: now, beside the symbol.
    Row {
        id: nowRow
        visible: root.ready && root.sizeClass !== "S"
        anchors { left: parent.left; top: head.bottom; topMargin: Tokens.gap * 0.6 }
        spacing: Tokens.gap * 1.2
        readonly property real h: root.sizeClass === "M" ? Math.max(36, root.height - head.height - hourRow.height - Tokens.gap * 1.6) : Tokens.islandHeight * 2.2
        height: h
        WeatherGlyph { kind: root.sym; day: root.now ? root.now.isDay : true; size: Math.min(nowRow.h, 72); anchors.verticalCenter: parent.verticalCenter }
        Metric {
            anchors.verticalCenter: parent.verticalCenter
            value: root.ready ? String(Math.round(root.now.temp)) : ""
            unit: "°"
            size: Math.max(22, Math.min(nowRow.h * 0.72, 52))
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Label { text: root.ready ? Weather.describe(root.now.code) : ""; font.weight: Font.Medium }
            Label { visible: root.options.details !== false; text: root.ready ? "Feels like " + Math.round(root.now.feels) + "°" : ""; role: "dim"; size: Tokens.textSmall }
        }
    }
    // ---- L: wind and humidity, as chips.
    Row {
        id: chips
        visible: root.ready && root.sizeClass !== "S" && root.sizeClass !== "M" && root.options.details !== false
        anchors { left: parent.left; top: nowRow.bottom; topMargin: Tokens.gap * 0.6 }
        spacing: 6
        Repeater {
            model: root.ready ? [{ i: "wind", t: Math.round(root.now.wind) + " " + Weather.windUnit }, { i: "humidity", t: Math.round(root.now.humidity) + "%" }] : []
            delegate: Rectangle {
                required property var modelData
                height: Tokens.islandHeight * 0.9; radius: Tokens.radiusInner
                width: chipRow.implicitWidth + Tokens.padding
                color: Colors.alpha(Colors.text, 0.07)
                Row { id: chipRow; anchors.centerIn: parent; spacing: 4
                      Icon { name: modelData.i; size: Tokens.textSmall + 3; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                      Label { text: modelData.t; size: Tokens.textSmall; numeric: true; anchors.verticalCenter: parent.verticalCenter } }
            }
        }
    }
    // ---- the next hours.
    Row {
        id: hourRow
        visible: root.ready && root.sizeClass !== "S" && root.hoursShown > 0
        height: visible ? implicitHeight : 0
        anchors { left: parent.left; right: parent.right; bottom: root.sizeClass === "M" ? parent.bottom : undefined; top: root.sizeClass === "M" ? undefined : chips.visible ? chips.bottom : nowRow.bottom; topMargin: Tokens.gap }
        Repeater {
            model: root.hours.slice(0, root.hoursShown)
            delegate: Column {
                required property var modelData
                width: hourRow.width / Math.max(1, root.hoursShown)
                spacing: 2
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(new Date(modelData.time), "HH"); role: "dim"; size: Tokens.textSmall; numeric: true }
                WeatherGlyph { anchors.horizontalCenter: parent.horizontalCenter; kind: Weather.symbol(modelData.code, true); size: Tokens.iconSize * 1.3 }
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(modelData.temp) + "°"; size: Tokens.textSmall + 1; numeric: true; font.weight: Font.Medium }
            }
        }
    }
    // ---- L: the next days.
    Column {
        visible: root.ready && (root.sizeClass === "L" || root.sizeClass === "XL")
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        spacing: 2
        Repeater {
            model: root.days
            delegate: Item {
                required property var modelData
                width: parent.width; height: Tokens.textSize * 2
                Label { anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.32; text: Qt.formatDate(new Date(modelData.date), "dddd"); size: Tokens.textSmall + 1 }
                WeatherGlyph { anchors.verticalCenter: parent.verticalCenter; x: parent.width * 0.34; kind: Weather.symbol(modelData.code, true); size: Tokens.iconSize * 1.15 }
                // The day's range as an M3 bar, between the week's coldest and warmest.
                Meter {
                    readonly property real lo: Math.min(...root.days.map(d => d.min))
                    readonly property real hi: Math.max(...root.days.map(d => d.max))
                    anchors.verticalCenter: parent.verticalCenter
                    x: parent.width * 0.48; width: parent.width * 0.32
                    value: hi > lo ? (modelData.max - lo) / (hi - lo) : 1
                    color: Colors.meaning(0.08)
                    thickness: 4
                }
                Label { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; numeric: true; size: Tokens.textSmall + 1
                        text: Math.round(modelData.min) + "° / " + Math.round(modelData.max) + "°" }
            }
        }
    }
}
