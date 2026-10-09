import QtQuick
import qs.services
import qs.theme
import qs.components
import "../../lib/calendar.js" as Cal

// Month grid (scroll or arrows to change month) with a dot on days that have
// events; the picked day's events, and a line to add one ("14:30 Dentist");
// when located, today's weather and the next days.
Column {
    id: root
    spacing: Tokens.gap
    property date month: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    readonly property date today: new Date()
    readonly property int cell: Tokens.islandHeight
    width: cell * 7 + Tokens.gap * 6
    property date picked: new Date()
    readonly property int lead: (month.getDay() - Qt.locale().firstDayOfWeek + 7) % 7
    readonly property date gridStart: new Date(month.getFullYear(), month.getMonth(), 1 - lead)
    onGridStartChanged: Events.show(gridStart, 42)
    Component.onCompleted: Events.show(gridStart, 42)

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
                readonly property bool isPicked: day.toDateString() === root.picked.toDateString()
                readonly property bool busy: Cal.on(Events.events, day).length > 0
                width: root.cell; height: root.cell; radius: width / 2
                color: isToday ? Colors.accent : isPicked ? Colors.alpha(Colors.accent, 0.22) : "transparent"
                Label { anchors.centerIn: parent; text: parent.day.getDate(); numeric: true
                        role: parent.isToday ? "onAccent" : parent.inMonth ? "text" : "dim"; opacity: parent.inMonth ? 1 : 0.5 }
                Rectangle { visible: parent.busy; width: 4; height: 4; radius: 2; anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 3 }
                            color: parent.isToday ? Colors.onAccent : Colors.accent }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.picked = parent.day }
            }
        }
    }
    WheelHandler { onWheel: e => root.month = new Date(root.month.getFullYear(), root.month.getMonth() + (e.angleDelta.y > 0 ? -1 : 1), 1) }

    // The picked day: its events, and a line to add one.
    Card {
        width: parent.width
        Column {
            width: root.width - 2 * Tokens.padding
            spacing: Tokens.gap / 2
            Label { text: Qt.formatDate(root.picked, "dddd, d MMMM"); font.weight: Font.DemiBold }
            Repeater {
                model: Cal.on(Events.events, root.picked)
                Row {
                    required property var modelData
                    width: parent.width
                    spacing: Tokens.gap
                    Label { width: Tokens.islandHeight * 1.4; text: Cal.timeOf(modelData) || "all day"; role: "dim"; size: Tokens.textSmall; numeric: true; anchors.verticalCenter: parent.verticalCenter }
                    Label { width: parent.width - Tokens.islandHeight * 1.4 - Tokens.iconSize - 2 * Tokens.gap; text: modelData.title + (modelData.location ? " · " + modelData.location : ""); elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                    Icon { name: "close"; size: Tokens.iconSize * 0.8; color: Colors.textDim; anchors.verticalCenter: parent.verticalCenter
                           MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: Events.remove(modelData.uid) } }
                }
            }
            Rectangle {
                width: parent.width; height: Tokens.islandHeight; radius: height / 2
                color: Colors.alpha(Colors.text, newEvent.activeFocus ? 0.12 : 0.06)
                TextInput {
                    id: newEvent
                    anchors { fill: parent; leftMargin: Tokens.padding; rightMargin: Tokens.padding }
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Tokens.fontText; font.pixelSize: Tokens.textSize
                    color: Colors.text; selectionColor: Colors.accent; clip: true
                    onAccepted: { const q = Cal.parseQuick(text); if (q && q.title) { Events.add(q.title, root.picked, q.time, q.minutes); text = ""; } }
                    Label { visible: !newEvent.text; text: "Add: 14:30 Dentist, or a title for all day"; role: "dim"; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }

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
