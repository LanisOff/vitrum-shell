import QtQuick
import qs.services
import qs.theme
import qs.components

// Now: symbol, temperature, description; the next hours underneath.
Item {
    id: root
    property var options: ({})
    WidgetHeader { id: head; icon: "weather-partly"; title: "Weather"; trailing: (Weather.place || "").split(",")[0] }
    Column {
        anchors.centerIn: parent
        visible: !Weather.ready
        spacing: Tokens.gap
        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "weather-cloudy"; size: Tokens.iconSize * 2; color: Colors.textDim }
        Label { anchors.horizontalCenter: parent.horizontalCenter; role: "dim"; size: Tokens.textSmall
                text: !Weather.located ? "Set a location in Settings" : Weather.error ? Weather.error : "Loading…" }
    }
    // Now, in whatever height the header and the hours leave: the symbol, the
    // temperature, and what it is like beside them.
    readonly property real nowH: height - head.height - (hours.visible ? hours.height + Tokens.gap * 0.5 : 0) - 2
    Row {
        id: now
        visible: Weather.ready
        anchors { left: parent.left; top: head.bottom; topMargin: 2 }
        height: root.nowH
        spacing: Tokens.gap
        readonly property string sym: Weather.ready ? Weather.symbol(Weather.current.code, Weather.current.isDay) : "weather-clear"
        WeatherGlyph { kind: now.sym; day: Weather.ready ? Weather.current.isDay : true; size: Math.max(24, Math.min(root.nowH * 1.05, 68)); anchors.verticalCenter: parent.verticalCenter }
        Label { text: Weather.ready ? Math.round(Weather.current.temp) + "°" : ""; numeric: true; size: Math.max(20, Math.min(root.nowH * 0.78, 48)); font.weight: Font.Light; anchors.verticalCenter: parent.verticalCenter }
        Label { text: Weather.ready ? Weather.describe(Weather.current.code) : ""; role: "dim"; size: Tokens.textSmall; anchors.verticalCenter: parent.verticalCenter }
    }
    Row {
        id: hours
        visible: Weather.ready && root.height > 120
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        Repeater {
            model: Weather.hourly.slice(1, 6)
            delegate: Column {
                required property var modelData
                width: root.width / 5
                spacing: 2
                readonly property string sym: Weather.symbol(modelData.code, true)
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(new Date(modelData.time), "HH"); role: "dim"; size: Tokens.textSmall; numeric: true }
                WeatherGlyph { anchors.horizontalCenter: parent.horizontalCenter; kind: parent.sym; size: Tokens.iconSize * 1.45 }
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(modelData.temp) + "°"; size: Tokens.textSmall + 1; numeric: true; font.weight: Font.DemiBold }
            }
        }
    }
}
