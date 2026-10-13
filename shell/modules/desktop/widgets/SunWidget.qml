import QtQuick
import QtQuick.Shapes
import qs.services
import qs.theme
import qs.components

/*
 * Sunrise and sunset where you are (Sun; the place is the weather's, set in Settings → Time).
 *   S   the next of the two: its icon, its time big, which one it is under it
 *       (and the length of the day, with daylight on)
 *   M   the header; the day as an arc from sunrise to sunset with the sun on
 *       it now, the two times under its ends, the length of the day between
 * options: daylight (show the length of the day).
 * In a gallery card with no times yet, a sample day stands in.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    property date now: new Date()
    Timer { interval: 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }

    function valid(d) { return d instanceof Date && !isNaN(d.getTime()); }
    readonly property bool known: valid(Sun.sunrise) && valid(Sun.sunset)
    readonly property bool sample: preview && !known
    readonly property bool ready: known || sample
    readonly property bool located: Sun.lat !== 0 || Sun.lon !== 0
    readonly property bool daylight: options.daylight !== false
    readonly property bool h24: Settings.get("clock.h24", true)

    // Minutes after midnight. The times are fetched for one day and kept
    // across midnight until the next fetch; a day later they are near enough.
    function minutes(d) { return d.getHours() * 60 + d.getMinutes(); }
    readonly property int riseMin: sample ? 6 * 60 + 48 : known ? minutes(Sun.sunrise) : 0
    readonly property int setMin: sample ? 19 * 60 + 42 : known ? minutes(Sun.sunset) : 0
    readonly property int nowMin: minutes(now)
    readonly property int dayLen: Math.max(0, setMin - riseMin)
    /// Where the sun is between sunrise (0) and sunset (1); outside the day, at the nearer end.
    readonly property real progress: dayLen > 0 ? Math.max(0, Math.min(1, (nowMin - riseMin) / dayLen)) : 0
    readonly property bool isDay: nowMin >= riseMin && nowMin < setMin
    readonly property bool nextIsSet: isDay
    readonly property int nextMin: nextIsSet ? setMin : riseMin

    function clock(m) {
        const d = new Date(2026, 0, 1, Math.floor(m / 60), m % 60);
        return Qt.formatTime(d, h24 ? "HH:mm" : "h:mm AP");
    }
    function span(m) { return Math.floor(m / 60) + " h " + (m % 60) + " min"; }
    // How long until the next one, "in 2 h 5 min" (tomorrow's sunrise after the sunset).
    readonly property string until: {
        let left = nextMin - nowMin;
        if (left < 0) left += 1440;
        return left < 60 ? "in " + left + " min" : "in " + span(left);
    }

    readonly property color sunColor: Colors.meaning(0.12)

    WidgetHeader {
        id: head
        visible: root.sizeClass !== "S"
        height: visible ? implicitHeight : 0
        icon: "sun"; title: "Sun"
        tint: root.sunColor
        trailing: root.ready ? (root.nextIsSet ? "Sunset " : "Sunrise ") + root.until : ""
    }
    WidgetEmpty {
        visible: !root.ready
        icon: "sunrise"
        text: root.located ? "Loading…" : "Set a location in Settings → Time"
    }

    // ---- S: the next one.
    Column {
        visible: root.ready && root.sizeClass === "S"
        anchors.centerIn: parent
        width: root.width
        spacing: 2
        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "sunrise"
            size: Math.round(root.height * 0.26)
            color: root.nextIsSet ? Colors.meaning(0.06) : root.sunColor
            filled: true
        }
        Metric {
            anchors.horizontalCenter: parent.horizontalCenter
            value: root.clock(root.nextMin).replace(/ ?[AP]M$/i, "")
            unit: root.h24 ? "" : (root.nextMin < 720 ? "AM" : "PM")
            size: Math.round(Math.min(root.height * 0.26, root.width / (root.h24 ? 3.2 : 4.2)))
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: root.nextIsSet ? "Sunset" : "Sunrise"
            role: "dim"; size: Tokens.textSmall
        }
        Label {
            visible: root.daylight
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: root.span(root.dayLen) + " of day"
            role: "dim"; size: Tokens.textSmall
        }
    }

    // ---- M: the arc of the day.
    Item {
        id: sky
        visible: root.ready && root.sizeClass !== "S"
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: foot.top; topMargin: Tokens.gap * 0.6; bottomMargin: 4 }
        // The horizon at the bottom; the arc's peak a little under the top.
        readonly property real dot: Math.max(10, Tokens.textSize * 0.9)
        readonly property real cx: width / 2
        readonly property real cy: height - dot / 2
        readonly property real rx: Math.max(10, width / 2 - Tokens.gap * 2.2)
        readonly property real ry: Math.max(10, height - dot)
        property real shown: root.progress
        Behavior on shown { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }

        Rectangle {
            x: 0; width: parent.width; height: Tokens.hairline
            y: sky.cy
            color: Colors.alpha(Colors.text, 0.18)
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Colors.alpha(root.sunColor, 0.22); strokeWidth: 3
                fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: sky.cx; centerY: sky.cy; radiusX: sky.rx; radiusY: sky.ry; startAngle: 180; sweepAngle: 180 }
            }
            // The part of the day gone by.
            ShapePath {
                strokeColor: root.sunColor; strokeWidth: 3
                fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: sky.cx; centerY: sky.cy; radiusX: sky.rx; radiusY: sky.ry; startAngle: 180; sweepAngle: Math.max(0.5, 180 * sky.shown) }
            }
        }
        // The sun now; at night a dim one waiting at the end it rises from or set at.
        Rectangle {
            readonly property real a: Math.PI * (1 + sky.shown)
            width: sky.dot; height: width; radius: width / 2
            x: sky.cx + sky.rx * Math.cos(a) - width / 2
            y: sky.cy + sky.ry * Math.sin(a) - height / 2
            color: root.isDay ? root.sunColor : Colors.textDim
            border.width: 2; border.color: Colors.alpha(root.isDay ? root.sunColor : Colors.textDim, 0.3)
        }
    }
    Item {
        id: foot
        visible: sky.visible
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: visible ? Tokens.textSize * 2.4 : 0
        Column {
            x: Math.max(0, Math.min(sky.cx - sky.rx - width / 2, parent.width - width))
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: root.clock(root.riseMin); numeric: true; font.weight: Font.Medium }
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Sunrise"; role: "dim"; size: Tokens.textSmall }
        }
        Column {
            visible: root.daylight
            anchors.horizontalCenter: parent.horizontalCenter
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: root.span(root.dayLen); numeric: true }
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Day length"; role: "dim"; size: Tokens.textSmall }
        }
        Column {
            x: Math.max(0, Math.min(sky.cx + sky.rx - width / 2, parent.width - width))
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: root.clock(root.setMin); numeric: true; font.weight: Font.Medium }
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Sunset"; role: "dim"; size: Tokens.textSmall }
        }
    }
}
