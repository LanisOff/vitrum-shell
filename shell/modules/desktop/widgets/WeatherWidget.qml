import QtQuick
import qs.services
import qs.theme
import qs.components

/*
 * The weather where you are (Weather; the place is set in Settings → Time).
 *   S   the symbol and the temperature, what it is like under them
 *   M   the header; now (symbol, temperature, what it is like, feels like);
 *       the next hours along the bottom
 *   L   as M, with wind and humidity as small glass badges, and the next days,
 *       each with its range as a tinted bar
 * options: hours (hours ahead shown, 0 hides them), details (feels like, wind, humidity).
 * In a gallery card with no weather yet, a sample day stands in.
 * Every size keeps to its frame: a row that does not fit (the header, the
 * hours, the badges, a day, what it is like under S's number) is left out
 * whole rather than drawn past the edge.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    readonly property bool sample: preview && !Weather.ready
    readonly property var now: sample ? { temp: 18, feels: 17, code: 2, humidity: 64, wind: 12, isDay: true } : Weather.current
    // From `now` itself, and every reading below asks `now`, not `ready`: when
    // the first data came, a binding woken through Weather.ready → ready read
    // `now` before its own binding had caught up, still null (TypeErrors).
    readonly property bool ready: !!now
    readonly property var hours: sample ? [19, 20, 21, 22, 23, 0, 1, 2].map((h, i) => ({ time: new Date(2026, 0, 1, h).getTime(), temp: 18 - i * 0.7, code: i < 3 ? 2 : 3 }))
                                        : Weather.hourly.slice(1)
    readonly property var days: sample ? [0, 1, 2, 3].map(i => ({ date: new Date(2026, 0, 2 + i).getTime(), code: [2, 61, 3, 0][i], max: 19 - i, min: 9 + i % 2 }))
                                       : Weather.daily.slice(1, 5)
    readonly property string sym: now ? Weather.symbol(now.code, now.isDay) : "weather-clear"
    readonly property int hoursShown: Math.max(0, Math.min(8, options.hours !== undefined ? options.hours : 5))

    // ---- the layout, top down, as plain y positions (no anchors switched by
    // size: a top anchor left over from an earlier size class pulled the
    // hours' bottom-anchored row to a negative height, and "now" grew by it).
    readonly property bool tall: sizeClass === "L" || sizeClass === "XL"
    readonly property real nowMin: 36
    readonly property real nowTop: head.visible ? head.height + Tokens.gap * 0.6 : 0
    readonly property real hourH: hourRow.implicitHeight
    // M: the hours along the bottom when "now" keeps its least height above them.
    readonly property bool hoursOn: ready && sizeClass !== "S" && hoursShown > 0
                                    && (tall ? hoursTop + hourH <= height
                                             : height - nowTop - hourH - Tokens.gap >= nowMin)
    readonly property real nowH: tall ? Tokens.islandHeight * 2.2
                                      : Math.max(0, height - nowTop - (hoursOn ? hourH + Tokens.gap : 0))
    readonly property real chipsTop: nowTop + nowH + Tokens.gap * 0.6
    readonly property bool chipsOn: ready && tall && options.details !== false && chipsTop + chipH <= height
    readonly property real chipH: Tokens.islandHeight * 0.9
    readonly property real hoursTop: tall ? (chipsOn ? chipsTop + chipH : nowTop + nowH) + Tokens.gap : height - hourH
    // L, XL: as many of the next days as the room under the hours holds.
    readonly property real dayH: Tokens.textSize * 2
    readonly property real daysTop: (hoursOn ? hoursTop + hourH : chipsOn ? chipsTop + chipH : nowTop + nowH) + Tokens.gap
    readonly property int daysShown: !ready || !tall ? 0
        : Math.max(0, Math.min(days.length, Math.floor((height - daysTop + 2) / (dayH + 2))))

    WidgetHeader {
        id: head
        // Left out when "now" would not keep its least height under it.
        visible: root.sizeClass !== "S" && root.height >= implicitHeight + Tokens.gap * 0.6 + root.nowMin
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
        WeatherGlyph { id: sGlyph; anchors.horizontalCenter: parent.horizontalCenter; kind: root.sym; day: root.now ? root.now.isDay : true; size: root.height * 0.36 }
        Label { id: sTemp; anchors.horizontalCenter: parent.horizontalCenter; text: root.now ? Math.round(root.now.temp) + "°" : ""; numeric: true; size: Math.round(root.height * 0.26); font.weight: Font.Light }
        Label { anchors.horizontalCenter: parent.horizontalCenter; width: root.width; horizontalAlignment: Text.AlignHCenter
                visible: sGlyph.height + sTemp.height + implicitHeight + 2 * parent.spacing <= root.height
                text: root.now ? Weather.describe(root.now.code) : ""; role: "dim"; size: Tokens.textSmall }
    }

    // ---- M and L: now, beside the symbol.
    Row {
        id: nowRow
        visible: root.ready && root.sizeClass !== "S"
        x: 0; y: root.nowTop
        width: root.width
        spacing: Tokens.gap * 1.2
        readonly property real h: root.nowH
        height: h
        WeatherGlyph { id: nowGlyph; kind: root.sym; day: root.now ? root.now.isDay : true; size: Math.min(nowRow.h, 72); anchors.verticalCenter: parent.verticalCenter }
        Metric {
            id: nowTemp
            anchors.verticalCenter: parent.verticalCenter
            value: root.now ? String(Math.round(root.now.temp)) : ""
            unit: "°"
            size: Math.min(nowRow.h * 0.72, 52)
        }
        // What is left of the width; a long description is cut, not run past the edge.
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, nowRow.width - nowGlyph.width - nowTemp.width - 2 * nowRow.spacing)
            Label { id: nowWhat; width: parent.width; text: root.now ? Weather.describe(root.now.code) : ""; font.weight: Font.Medium }
            Label { width: parent.width; visible: root.options.details !== false && nowWhat.height + implicitHeight <= nowRow.h
                    text: root.now ? "Feels like " + Math.round(root.now.feels) + "°" : ""; role: "dim"; size: Tokens.textSmall }
        }
    }
    // ---- L: wind and humidity, as badges of clear glass (radiusButton).
    Row {
        id: chips
        visible: root.chipsOn
        x: 0; y: root.chipsTop
        spacing: Math.round(Tokens.gap * 0.5)
        Repeater {
            model: root.now ? [{ i: "wind", t: Math.round(root.now.wind) + " " + Weather.windUnit }, { i: "humidity", t: Math.round(root.now.humidity) + "%" }] : []
            delegate: Rectangle {
                required property var modelData
                height: root.chipH; radius: Tokens.radiusButton
                width: chipRow.implicitWidth + Tokens.padding
                color: Colors.dark ? Qt.rgba(1, 1, 1, 0.05) : Colors.alpha(Colors.text, 0.05)
                border.width: Tokens.hairline
                border.color: Colors.dark ? Qt.rgba(1, 1, 1, 0.08) : Colors.alpha(Colors.text, 0.08)
                Row { id: chipRow; anchors.centerIn: parent; spacing: 4
                      Icon { name: modelData.i; size: Tokens.textSmall + 3; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                      Label { text: modelData.t; size: Tokens.textSmall; numeric: true; anchors.verticalCenter: parent.verticalCenter } }
            }
        }
    }
    // ---- the next hours.
    Row {
        id: hourRow
        visible: root.hoursOn
        x: 0; y: root.hoursTop
        width: root.width
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
        visible: root.daysShown > 0
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        spacing: 2
        Repeater {
            model: root.days.slice(0, root.daysShown)
            delegate: Item {
                required property var modelData
                width: parent.width; height: root.dayH
                Label { anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.32; text: Qt.formatDate(new Date(modelData.date), "dddd"); size: Tokens.textSmall + 1 }
                WeatherGlyph { anchors.verticalCenter: parent.verticalCenter; x: parent.width * 0.34; kind: Weather.symbol(modelData.code, true); size: Tokens.iconSize * 1.15 }
                // The day's range, from its low to its high, as a tinted bar in a
                // glass groove that runs from the week's coldest to its warmest.
                Item {
                    id: range
                    readonly property real lo: Math.min(...root.days.map(d => d.min))
                    readonly property real hi: Math.max(...root.days.map(d => d.max))
                    readonly property real low: hi > lo ? (modelData.min - lo) / (hi - lo) : 0
                    readonly property real high: hi > lo ? (modelData.max - lo) / (hi - lo) : 1
                    anchors.verticalCenter: parent.verticalCenter
                    x: parent.width * 0.48; width: parent.width * 0.32
                    height: Tokens.radiusMeter * 2
                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.radiusMeter
                        color: Colors.dark ? Qt.rgba(1, 1, 1, 0.07) : Colors.alpha(Colors.text, 0.07)
                        border.width: Tokens.hairline
                        border.color: Colors.dark ? Qt.rgba(1, 1, 1, 0.06) : Colors.alpha(Colors.text, 0.06)
                    }
                    ShellTint {
                        x: Math.min(range.width - width, range.width * range.low)
                        width: Math.max(range.height, range.width * (range.high - range.low)); height: range.height
                        radius: Tokens.radiusMeter
                        group: "widgets"
                        tint: Colors.meaning(0.08)
                        // Data: a touch more colour than a tinted control, as Meter's fill.
                        alphaStart: Colors.dark ? 0.62 : 0.55
                        alphaMiddle: Colors.dark ? 0.52 : 0.45
                        alphaEnd: Colors.dark ? 0.60 : 0.52
                    }
                }
                Label { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; numeric: true; size: Tokens.textSmall + 1
                        text: Math.round(modelData.min) + "° / " + Math.round(modelData.max) + "°" }
            }
        }
    }
}
