import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components
import qs.common
import Quickshell.Io

Page {
    title: "Notifications"
    Section {
        SettingChoice { key: "notifications.position"; names: ({ "top-right": "Top right", "top-left": "Top left", "bottom-right": "Bottom right", "bottom-left": "Bottom left" }) }
        SettingChoice { key: "notifications.screen"; names: ({ focused: "Focused screen", primary: "Primary screen" }) }
        SettingToggle { key: "sounds.notification"; label: "Play a sound" }
        SettingSlider { key: "notifications.timeout"; label: "Shown for"; from: 2; to: 20; step: 1; unit: " s"; divider: false }
    }
    // The shell owns notifications (and the notification server): asked and told over its IPC.
    property bool dnd: false
    Process { id: askDnd; running: true; command: ["vitrum-ipc", "notifications", "isDnd"]; stdout: StdioCollector { onStreamFinished: dndPage.dnd = text.trim() === "true" } }
    Timer { id: reask; interval: 300; onTriggered: askDnd.running = true }
    id: dndPage
    Section {
        title: "Do not disturb"
        SettingRow {
            label: "Do not disturb"; hint: "Toasts stay quiet; the Notification Centre keeps everything."; divider: false
            Toggle { checked: dndPage.dnd; onToggled: { Quickshell.execDetached(["vitrum-ipc", "notifications", "dnd"]); dndPage.dnd = !dndPage.dnd; reask.restart(); } }
        }
    }
}
