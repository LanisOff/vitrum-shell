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
    Section {
        id: cal
        title: "Calendar"
        SettingRow {
            label: Events.status.connected ? (Events.status.kind === "google" ? "Google Calendar" : "CalDAV") + " connected" : "Only this computer"
            hint: Events.status.connected ? (Events.status.calendars.length - 1) + " calendars synced every 15 minutes, besides the local one." : "Events are kept here until you connect a server."
            Capsule { visible: Events.status.connected; label: "Sync now"; onClicked: Events.syncNow() }
            Capsule { visible: Events.status.connected; label: "Disconnect"; onClicked: Events.disconnect() }
        }
        SettingSlider { key: "calendar.remindMinutes"; label: "Remind before"; from: 0; to: 60; step: 5; unit: " min" }
        Column {
            visible: !Events.status.connected
            width: parent.width
            spacing: Tokens.gap
            padding: Tokens.padding
            Label { text: "CalDAV (Nextcloud, Yandex, iCloud, Fastmail…)"; font.weight: Font.DemiBold }
            component Field: Rectangle {
                property alias text: input.text
                property alias echo: input.echoMode
                property string hint: ""
                width: cal.width - 4 * Tokens.padding; height: Tokens.islandHeight; radius: height / 2
                color: Colors.alpha(Colors.text, input.activeFocus ? 0.12 : 0.06)
                TextInput { id: input; anchors.fill: parent; anchors.leftMargin: Tokens.padding; anchors.rightMargin: Tokens.padding; verticalAlignment: TextInput.AlignVCenter
                            color: Colors.text; font.family: Tokens.fontText; font.pixelSize: Tokens.textSize; clip: true
                            Label { visible: !input.text; text: parent.parent.hint; role: "dim"; anchors.verticalCenter: parent.verticalCenter } }
            }
            Field { id: url; hint: "Server address, e.g. https://cloud.example.com/remote.php/dav" }
            Field { id: user; hint: "User name" }
            Field { id: pass; hint: "App password"; echo: TextInput.Password }
            Capsule { label: "Connect"; active: true; onClicked: { Events.connect(url.text.trim(), user.text.trim(), pass.text); pass.text = ""; } }
            Label { visible: text.length > 0; text: Events.connectResult; role: "dim"; size: Tokens.textSmall; width: cal.width - 4 * Tokens.padding; wrapMode: Text.WordWrap }
            Label { text: "Google Calendar"; font.weight: Font.DemiBold; topPadding: Tokens.gap }
            Label { width: cal.width - 4 * Tokens.padding; wrapMode: Text.WordWrap; role: "dim"; size: Tokens.textSmall
                    text: "Google needs an OAuth client of your own (Google Cloud console → APIs → Credentials → OAuth client, type Desktop). Paste its id and secret; the sign-in opens in your browser." }
            Field { id: gid; hint: "Client id" }
            Field { id: gsecret; hint: "Client secret" }
            Capsule { label: "Sign in with Google"; onClicked: Events.connectGoogle(gid.text.trim(), gsecret.text.trim()) }
        }
    }
}
