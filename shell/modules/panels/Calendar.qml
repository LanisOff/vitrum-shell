import QtQuick
import qs.services
import qs.theme
import qs.components

// Month grid (scroll or arrows to change month); when located, today's
// weather and the next days.
Column {
    id: root
    spacing: Tokens.gap
    property date month: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    readonly property date today: new Date()
    readonly property int cell: Tokens.islandHeight
    width: cell * 7 + Tokens.gap * 6

    Row {
        width: parent.width
        Label { text: Qt.formatDate(root.month, "MMMM yyyy"); size: Tokens.textLarge; font.weight: Font.DemiBold; width: parent.width - 2 * Tokens.islandHeight }
        Capsule { icon: "chevron"; rotation: 180; implicitWidth: Tokens.islandHeight; onClicked: root.month = new Date(root.month.getFullYear(), root.month.getMonth() - 1, 1) }
        Capsule { icon: "chevron"; implicitWidth: Tokens.islandHeight; onClicked: root.month = new Date(root.month.getFullYear(), root.month.getMonth() + 1, 1) }
    }

    Grid {
        columns: 7
        spacing: Tokens.gap
        Repeater {
            model: 7
            Label { required property int index; width: root.cell; horizontalAlignment: Text.AlignHCenter; role: "dim"; size: Tokens.textSmall
                    text: Qt.locale().dayName((index + Qt.locale().firstDayOfWeek) % 7, Locale.NarrowFormat) }
        }
        Repeater {
            // 6 weeks starting on the locale's first weekday
            model: 42
            delegate: Rectangle {
                required property int index
                readonly property int lead: (root.month.getDay() - Qt.locale().firstDayOfWeek + 7) % 7
                readonly property date day: new Date(root.month.getFullYear(), root.month.getMonth(), index - lead + 1)
                readonly property bool inMonth: day.getMonth() === root.month.getMonth()
                readonly property bool isToday: day.toDateString() === root.today.toDateString()
                width: root.cell; height: root.cell; radius: width / 2
                color: isToday ? Colors.accent : "transparent"
                Label { anchors.centerIn: parent; text: parent.day.getDate(); numeric: true
                        role: parent.isToday ? "onAccent" : parent.inMonth ? "text" : "dim"; opacity: parent.inMonth ? 1 : 0.5 }
            }
        }
    }
    WheelHandler { onWheel: e => root.month = new Date(root.month.getFullYear(), root.month.getMonth() + (e.angleDelta.y > 0 ? -1 : 1), 1) }

    // Weather, when the location is set in settings.
    Card {
        visible: Weather.ready
        width: parent.width
        Row {
            id: wnow
            spacing: Tokens.gap * 1.5
            WeatherGlyph { kind: Weather.ready ? Weather.symbol(Weather.current.code, Weather.current.isDay) : "weather-cloudy"; day: Weather.ready ? Weather.current.isDay : true; size: Tokens.iconSize * 2.6; anchors.verticalCenter: parent.verticalCenter }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                // The card's width, not the text's: a long place name used to run off its edge.
                width: root.width - Tokens.iconSize * 2.6 - Tokens.gap * 1.5 - 2 * Tokens.padding
                Label { text: Weather.ready ? Math.round(Weather.current.temp) + Weather.unit : ""; size: Tokens.textTitle; numeric: true }
                Label { width: parent.width; elide: Text.ElideRight
                        text: ((Weather.place || "").split(",")[0] ? (Weather.place || "").split(",")[0] + " · " : "") + (Weather.ready ? Weather.describe(Weather.current.code) : ""); role: "dim" }
            }
        }
    }
    Row {
        visible: Weather.ready && Weather.daily.length > 1
        spacing: Tokens.gap
        Repeater {
            model: Weather.daily.slice(1, 6)
            Card {
                required property var modelData
                width: (root.width - 4 * Tokens.gap) / 5
                Column {
                    spacing: 2
                    Label { text: Qt.formatDate(new Date(modelData.date), "ddd"); role: "dim"; size: Tokens.textSmall }
                    WeatherGlyph { kind: Weather.symbol(modelData.code, true); size: Tokens.iconSize * 1.6 }
                    Label { text: Math.round(modelData.max) + "° " + Math.round(modelData.min) + "°"; numeric: true; size: Tokens.textSmall }
                }
            }
        }
    }
}
