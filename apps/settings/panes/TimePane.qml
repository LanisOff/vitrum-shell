import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components
import qs.common

Page {
    title: "Date & time"
    Section {
        title: "Clock"
        SettingToggle { key: "clock.h24"; label: "24-hour clock" }
        SettingToggle { key: "clock.seconds"; label: "Show seconds"; divider: false }
    }
    Section {
        title: "Weather"
        note: "The location also gives sunrise and sunset for the automatic scheme."
        SettingText { key: "weather.place"; label: "Place name" }
        SettingText { key: "weather.latitude"; label: "Latitude"; numeric: true; fieldWidth: Tokens.islandHeight * 4 }
        SettingText { key: "weather.longitude"; label: "Longitude"; numeric: true; fieldWidth: Tokens.islandHeight * 4 }
        SettingRow {
            label: "Find my location"; hint: Weather.locating ? "Looking…" : "From your IP address (approximate)."
            Rectangle {
                height: Tokens.islandHeight * 1.05; radius: height / 2; width: dl.implicitWidth + Tokens.padding * 1.6
                color: Colors.alpha(Colors.text, 0.06)
                Label { id: dl; anchors.centerIn: parent; text: "Detect" }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Weather.detectLocation() }
            }
        }
        SettingChoice { key: "weather.units"; names: ({ metric: "Metric", imperial: "Imperial" }); divider: false }
    }
    Section {
        title: "Pomodoro"
        SettingSlider { key: "timers.work"; label: "Focus"; from: 10; to: 60; step: 5; unit: " min" }
        SettingSlider { key: "timers.short"; label: "Short break"; from: 1; to: 15; step: 1; unit: " min" }
        SettingSlider { key: "timers.long"; label: "Long break"; from: 5; to: 40; step: 5; unit: " min" }
        SettingSlider { key: "timers.rounds"; label: "Rounds before the long break"; from: 2; to: 8; step: 1; divider: false }
    }
}
