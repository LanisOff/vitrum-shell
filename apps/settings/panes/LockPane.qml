import QtQuick
import QtQuick.Dialogs
import Quickshell
import qs.services
import qs.theme
import qs.components
import qs.common

Page {
    title: "Lock & idle"
    Section {
        title: "When idle"
        SettingSlider { key: "lock.dimMinutes"; label: "Dim the screen after"; from: 0; to: 60; step: 1; unit: " min"; hint: "Any key or the mouse brings it back. 0 never dims." }
        SettingSlider { key: "lock.idleMinutes"; label: "Lock after"; from: 0; to: 60; step: 1; unit: " min"; hint: "0 never locks on its own." }
        SettingSlider { key: "lock.screenOffMinutes"; label: "Turn the screen off after"; from: 0; to: 120; step: 1; unit: " min"; hint: "0 leaves it on." }
        SettingToggle { key: "lock.beforeSleep"; label: "Lock before sleep"; hint: "Sleep waits until the lock is up, so waking never shows the desktop."; divider: false }
    }
    Section {
        title: "Lock screen"
        SettingRow {
            id: pic
            label: "Your picture"
            hint: "On the lock screen and at login (~/.face). Without one, your initial."
            readonly property string face: Quickshell.env("HOME") + "/.face"
            property int stamp: 0
            Rectangle {
                width: Tokens.islandHeight * 1.6; height: width; radius: width / 2
                color: Colors.alpha(Colors.accent, 0.25)
                RoundImage {
                    id: faceImg
                    anchors.fill: parent
                    radius: parent.radius
                    source: "file://" + pic.face + "?" + pic.stamp
                    cache: false
                }
                Icon { anchors.centerIn: parent; name: "user"; visible: faceImg.status !== Image.Ready; color: Colors.textDim }
            }
            Capsule { label: "Choose…"; onClicked: faceDialog.open() }
            Capsule { label: "Remove"; visible: faceImg.status === Image.Ready; onClicked: { Quickshell.execDetached(["rm", "-f", pic.face, pic.face + ".icon"]); faceTimer.restart(); } }
            // .face for the lock screen, .face.icon for SDDM; both a copy, so the
            // original picture can move or go.
            FileDialog {
                id: faceDialog
                title: "Your picture"
                nameFilters: ["Images (*.png *.jpg *.jpeg *.webp)"]
                onAccepted: {
                    const src = decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""));
                    Quickshell.execDetached(["sh", "-c", 'cp -f -- "$1" "$2" && cp -f -- "$1" "$2.icon" && chmod 644 "$2" "$2.icon"', "sh", src, pic.face]);
                    faceTimer.restart();
                }
            }
            Timer { id: faceTimer; interval: 600; onTriggered: pic.stamp++ }
        }
        SettingChoice { key: "lock.notifications"; label: "Notifications"; names: ({ off: "Off", apps: "App names only", full: "Full text" }); hint: "What arrived while locked, under the clock. Full text: click a group to open it; App names only keeps the text private." }
        SettingToggle { key: "lock.player"; label: "Player when something plays" }
        SettingSlider { key: "lock.ambientSeconds"; label: "Dim to the clock after"; from: 0; to: 60; step: 1; unit: " s"; hint: "Field and status fade until you touch a key or the mouse. 0 keeps everything shown." }
        SettingToggle { key: "lock.power"; label: "Power buttons"; hint: "Suspend at once; restart and power off ask for a second press."; divider: false }
    }
}
