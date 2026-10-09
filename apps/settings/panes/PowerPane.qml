import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components
import qs.common

Page {
    title: "Power & performance"
    Section {
        title: "Power profile"
        visible: Power.profiles.length > 0
        SettingRow {
            label: "Profile"; divider: false
            Repeater {
                model: Power.profiles
                delegate: Rectangle {
                    required property string modelData
                    readonly property bool on: Power.profile === modelData
                    height: Tokens.islandHeight * 1.05; radius: height / 2; width: pl.implicitWidth + Tokens.padding * 1.4
                    color: on ? Colors.accent : Colors.alpha(Colors.text, 0.06)
                    Label { id: pl; anchors.centerIn: parent; text: modelData === "power-saver" ? "Saver" : modelData.charAt(0).toUpperCase() + modelData.slice(1); role: parent.on ? "onAccent" : "text"; size: Tokens.textSmall + 1 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Power.setProfile(modelData) }
                }
            }
        }
    }
    Section {
        title: "Battery"
        visible: Power.hasBattery
        SettingRow { label: "Charge"; divider: false; Label { text: Math.round(Power.percentage) + "% · " + (Power.charging ? "charging" : Power.timeRemaining); role: "dim" } }
    }
    Section {
        title: "Stay awake"
        SettingToggle { key: "awake.media"; label: "Stay awake while something plays"; hint: "Music or a video playing anywhere: the screen does not dim, lock or turn off." }
        SettingToggle { key: "awake.auto"; label: "Stay awake during fullscreen video and games"; hint: "No idle lock while a fullscreen window plays a video or is a game. The coffee cup in Control Centre keeps it awake by hand."; divider: false }
    }
    Section {
        title: "Games"
        SettingToggle { key: "games.mode"; label: "Game mode"; hint: "While a game fills the screen: no animations or blur, notifications held back (critical ones still show), and the game gets gamemode's CPU boost." }
        SettingToggle { key: "games.hud"; label: "Show MangoHud in game mode"; hint: "FPS, frame time, CPU and GPU load and temperatures, in Steam's games. Mod+Shift+F toggles it." }
        SettingList { key: "games.extra"; label: "Also games"; hint: "Steam games and gamescope are recognised. Add an app id or part of a window title for anything else (e.g. minecraft)." }
    }
    Section {
        title: "Hardware alerts"
        SettingToggle { key: "alerts.enabled"; label: "Warn about the hardware"; hint: "Shown even in a game and in Do not disturb." }
        SettingSlider { key: "alerts.gpu"; label: "GPU hotter than"; from: 70; to: 100; step: 1; unit: " °C" }
        SettingSlider { key: "alerts.cpu"; label: "CPU hotter than"; from: 70; to: 105; step: 1; unit: " °C" }
        SettingSlider { key: "alerts.diskPercent"; label: "A disk fuller than"; from: 70; to: 99; step: 1; unit: " %" }
        SettingSlider { key: "alerts.diskFreeGB"; label: "Or with less free than"; from: 1; to: 100; step: 1; unit: " GB" }
        SettingToggle { key: "alerts.smart"; label: "Drive health (SMART)"; hint: "Every six hours, through vitrum's root helper."; divider: false }
    }
}
