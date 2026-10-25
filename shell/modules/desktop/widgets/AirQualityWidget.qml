import QtQuick
import qs.services
import qs.theme
import qs.components
import "../../../lib/airquality.js" as Lib

/*
 * The air where the weather is (AirQuality: Open-Meteo, the place set in
 * Settings → Time): the European AQI as a ring in its level's colour, what
 * the level means (good → extremely poor), and the two particle sizes.
 *   S   the ring, the index inside it, the level under it
 *   M   the header (the place at its end); the ring beside the level, and
 *       PM2.5 and PM10 as meters, each in its own level's colour
 * options: pollutants (the PM2.5 and PM10 meters at M).
 * Asked every half hour while it shows, not under a game. In a gallery card
 * with no reading yet, a sample one stands in.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    // preview is set after Component.onCompleted: subscribe a turn later, once it is known.
    property bool started: false
    Component.onCompleted: Qt.callLater(() => root.started = true)
    readonly property bool live: started && !preview
    onLiveChanged: live ? AirQuality.subscribe() : AirQuality.unsubscribe()
    Component.onDestruction: if (live) AirQuality.unsubscribe()

    readonly property bool sample: preview && !AirQuality.current
    readonly property var now: sample ? { aqi: 24, pm25: 8.4, pm10: 14.1 } : AirQuality.current
    readonly property bool ready: !!now && now.aqi !== null
    readonly property int lv: ready ? Lib.level(now.aqi) : -1
    readonly property color tone: Colors.meaning(Lib.hue(lv))
    readonly property bool pollutants: options.pollutants !== false
    readonly property string place: sample ? "Riga" : (Weather.place || "").split(",")[0]
    function fmt(v) { return v === null || v === undefined ? "—" : v < 10 ? v.toFixed(1) : String(Math.round(v)); }

    // What the level means, in the text colour (legible on any glass), after a
    // swatch of the level's colour: the colour is the ring's and the swatch's.
    // (Given, not looked up: an inline component does not see this file's ids.)
    component Level: Row {
        property int size: Tokens.textSize
        property real maxWidth: 200
        property color tone: Colors.accent
        property string text: ""
        spacing: Math.round(size * 0.4)
        Rectangle {
            width: Math.round(parent.size * 0.62); height: width
            anchors.verticalCenter: parent.verticalCenter
            // A swatch, not a dot: corners a fifth of its side.
            radius: Math.min(Tokens.radiusMark, Math.round(width * 0.2))
            color: parent.tone
        }
        Label {
            width: Math.min(implicitWidth, parent.maxWidth - parent.size)
            text: parent.text
            size: parent.size; font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    WidgetHeader {
        id: head
        visible: root.sizeClass !== "S"
        height: visible ? implicitHeight : 0
        icon: "leaf"; title: "Air quality"
        trailing: root.place
    }
    WidgetEmpty {
        visible: !root.ready
        icon: "leaf"
        text: !Weather.located && !root.preview ? "Set a location in Settings → Time"
            : AirQuality.error ? AirQuality.error : "Loading…"
    }

    // ---- S: the ring, the level under it.
    Column {
        visible: root.ready && root.sizeClass === "S"
        anchors.centerIn: parent
        spacing: Tokens.gap * 0.4
        readonly property real d: Math.max(48, Math.min(root.width, root.height - sLevel.height - spacing) * 0.92)
        Ring {
            id: sRing
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.d; height: width
            thickness: Math.max(6, width * 0.085)
            value: root.ready ? Lib.fraction(root.now.aqi) : 0
            color: root.tone
            Column {
                anchors.centerIn: parent
                Metric { anchors.horizontalCenter: parent.horizontalCenter; value: root.ready ? String(Math.round(root.now.aqi)) : ""; size: Math.round(sRing.width * 0.3) }
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: "AQI"; role: "dim"; size: Tokens.textSmall - 1 }
            }
        }
        Level { id: sLevel; anchors.horizontalCenter: parent.horizontalCenter; size: Tokens.textSmall + 1; maxWidth: root.width; tone: root.tone; text: Lib.label(root.lv) }
    }

    // ---- M: the ring beside the level and the meters.
    Item {
        id: area
        visible: root.ready && root.sizeClass !== "S"
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: Tokens.gap * 0.6; bottom: parent.bottom }
        Ring {
            id: mRing
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(area.height, area.width * 0.4); height: width
            thickness: Math.max(5, width * 0.09)
            value: root.ready ? Lib.fraction(root.now.aqi) : 0
            color: root.tone
            Metric { anchors.centerIn: parent; value: root.ready ? String(Math.round(root.now.aqi)) : ""; size: Math.round(mRing.width * 0.32) }
        }
        Column {
            id: side
            anchors { left: mRing.right; leftMargin: Tokens.gap * 1.2; right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: Tokens.gap * 0.5
            readonly property real meterH: Tokens.textSmall + 4 + 6 + 6
            // The meters only when both fit under the level.
            readonly property bool meters: root.pollutants && levelBox.height + 2 * (meterH + spacing) <= area.height
            Column {
                id: levelBox
                width: parent.width
                Level { size: Tokens.textSize + 2; maxWidth: parent.width; tone: root.tone; text: Lib.label(root.lv) }
                Label { width: parent.width; text: "European air quality index"; role: "dim"; size: Tokens.textSmall }
            }
            Repeater {
                model: side.meters && root.ready ? [{ k: "pm2_5", t: "PM2.5", v: root.now.pm25 }, { k: "pm10", t: "PM10", v: root.now.pm10 }] : []
                delegate: Meter {
                    required property var modelData
                    width: side.width
                    group: "widgets"
                    value: Lib.fraction(modelData.v, modelData.k)
                    color: Colors.meaning(Lib.hue(Lib.level(modelData.v, modelData.k)))
                    label: modelData.t
                    trailing: root.fmt(modelData.v) + " µg/m³"
                }
            }
        }
    }
}
