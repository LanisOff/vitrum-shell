import QtQuick
import QtQuick.Effects
import qs.services
import qs.theme
import qs.components
import "../../lock"

/*
 * The time.
 *   S   the time, the short date under it
 *   M   the time on one line, the date under it
 *   L   hours over minutes (one line with seconds), the date under them
 * options: style ("glass": digits cut out of glass, like the lock screen's —
 * no plate, the wallpaper bends through them (Desktop's backdrop); "digital":
 * plain light figures on the host's plate), hours ("24"/"12"), seconds, date.
 * Glass without a backdrop (solid widgets, a gallery card) is painted instead.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)
    // Bound by the host for glass content.
    property Item backdrop: null
    property Item source: null

    property date now: new Date()
    // The tick also re-places the glass over the backdrop: the desktop draws no
    // frames of its own to do it on, and the widget may have been moved.
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { root.now = new Date(); if (root.useGlass) glass._sync(); }
    }

    readonly property bool digital: options.style === "digital"
    readonly property bool useGlass: !digital && !preview && !!backdrop && Materials.of("widgets") !== "solid"
    // Bare on the wallpaper: white with a shadow. In a card or on a plate: the theme's ink.
    readonly property bool onWallpaper: !digital && !preview

    readonly property bool h12: options.hours === "12"
    readonly property bool secs: options.seconds === true
    readonly property bool showDate: options.date !== false
    readonly property string hh: Qt.formatTime(now, h12 ? "h" : "HH")
    readonly property string mm: Qt.formatTime(now, "mm")
    readonly property string ss: Qt.formatTime(now, "ss")
    readonly property bool stacked: sizeClass === "L" && !secs && height > width * 0.75
    readonly property var lines: stacked ? [hh, mm] : [hh + ":" + mm + (secs ? ":" + ss : "")]
    readonly property string ampm: h12 ? (now.getHours() < 12 ? "AM" : "PM") : ""

    readonly property int dateSize: sizeClass === "S" ? Tokens.textSmall
                                  : sizeClass === "M" ? Tokens.textSize
                                  : Tokens.textSize + 2
    readonly property string dateText: Qt.formatDate(now, sizeClass === "S" ? "ddd d MMM" : "dddd, d MMMM")
    // Figures run about 0.6 of the size wide and 1.2 tall; the date takes its line below.
    readonly property real longest: Math.max(...lines.map(l => l.length)) + (digital && h12 ? 1.4 : 0)
    readonly property real timeSize: {
        const roomH = height - (showDate ? dateSize * 1.5 + Tokens.gap * 0.3 : 0);
        const byH = roomH / (lines.length * (stacked ? 1.18 : 1.25));
        const byW = width * 0.92 / (longest * 0.6);
        return Math.max(20, Math.min(byH, byW));
    }

    // The digits: one line, or hours over minutes. A count for the model, so
    // the delegates stay and LockClock rolls the characters that change.
    component Digits: Column {
        id: digits
        property var lines: []
        property real size: 40
        property int weight: Font.Bold
        property color ink: "white"
        // Stacked figures sit closer than their line height.
        spacing: -size * 0.16
        Repeater {
            model: digits.lines.length
            delegate: LockClock {
                required property int index
                anchors.horizontalCenter: parent.horizontalCenter
                time: digits.lines[index] || ""
                size: digits.size
                weight: digits.weight
                color: digits.ink
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Tokens.gap * 0.3

        Glass {
            id: glass
            anchors.horizontalCenter: parent.horizontalCenter
            width: glassDigits.implicitWidth; height: glassDigits.implicitHeight
            visible: root.useGlass
            backdrop: root.useGlass ? root.backdrop : null
            source: root.useGlass ? root.source : null
            // Stronger than the lock's: there the picture around is blurred and
            // the clear digits stand out by themselves; here it is as sharp as
            // they are, so the rims carry the glass.
            bevel: root.timeSize * 0.14
            refraction: root.timeSize * 0.5
            edgeLight: 1.8
            fringing: 0.5
            saturation: 1.4
            brightness: 0.07
            tint: Qt.rgba(1, 1, 1, Colors.dark ? 0.05 : 0.12)
            shadow: 0.6
            Digits { id: glassDigits; lines: root.lines; size: root.timeSize; weight: Font.Bold; ink: "white" }
        }

        // Painted: the digital style, or glass with nothing to look through.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.useGlass
            height: visible ? implicitHeight : 0
            spacing: Math.round(root.timeSize * 0.08)
            Digits {
                id: painted
                lines: root.lines
                size: root.timeSize
                weight: root.digital ? Font.Light : Font.Bold
                ink: root.onWallpaper ? "white" : Colors.text
                layer.enabled: root.onWallpaper
                layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.7; shadowColor: Qt.rgba(0, 0, 0, 0.5); shadowVerticalOffset: 2 }
            }
            // AM/PM on the plate only: glass reads as digits alone.
            Label {
                visible: root.digital && root.h12
                y: painted.height - height - root.timeSize * 0.18
                text: root.ampm
                size: Math.max(Tokens.textSmall, Math.round(root.timeSize * 0.3))
                role: "dim"
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.showDate
            width: Math.min(implicitWidth, root.width)
            horizontalAlignment: Text.AlignHCenter
            text: root.dateText
            size: root.dateSize
            font.weight: root.digital ? Font.Normal : Font.DemiBold
            color: root.onWallpaper ? "white" : root.digital ? Colors.textDim : Colors.text
            // On the bare wallpaper: a soft shadow keeps it readable on light pictures.
            layer.enabled: root.onWallpaper
            layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.6; shadowColor: Qt.rgba(0, 0, 0, 0.55); shadowVerticalOffset: 1 }
        }
    }
}
