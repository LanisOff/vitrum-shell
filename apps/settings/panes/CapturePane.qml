import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components
import qs.common

Page {
    title: "Screenshots & recording"
    subtitle: "Print opens the capture toolbar; Mod+Shift+S selects an area; Mod+Shift+X copies text from the screen."
    Section {
        title: "Saving"
        SettingText { key: "capture.dir"; label: "Screenshots folder"; fieldWidth: Tokens.islandHeight * 12 }
        SettingText { key: "capture.videoDir"; label: "Recordings folder"; fieldWidth: Tokens.islandHeight * 12 }
        SettingToggle { key: "capture.copy"; label: "Copy screenshots to the clipboard" }
        SettingSlider { key: "capture.thumbnailSeconds"; label: "Thumbnail stays for"; from: 2; to: 20; step: 1; unit: " s" }
        SettingChoice { key: "capture.editor"; values: ["vitrum", "satty", "xdg-open"]; names: ({ vitrum: "The editor", satty: "Satty", "xdg-open": "Default app" }); label: "Click on the thumbnail opens"; divider: false }
    }
    Section {
        title: "Starting with"
        SettingChoice { key: "capture.mode"; names: ({ area: "Area", window: "Window", screen: "Screen" }) }
        SettingChoice { key: "capture.delay"; names: ({ 0: "None", 3: "3 s", 5: "5 s" }); divider: false }
    }
    Section {
        title: "Recording"
        SettingChoice { key: "capture.recorder"; names: ({ auto: "Automatic", "gpu-screen-recorder": "GPU Screen Recorder", "wf-recorder": "wf-recorder" }) }
        SettingSlider { key: "capture.fps"; label: "Frames per second"; from: 15; to: 120; step: 5 }
        SettingToggle { key: "capture.audio"; label: "Record the computer's sound" }
        SettingToggle { key: "capture.mic"; label: "Record the microphone"; hint: "Both switches are also on the capture toolbar while recording."; divider: false }
    }
    Section {
        title: "Text recognition"
        SettingText { key: "capture.ocrLanguages"; label: "Languages"; hint: "Tesseract language codes joined by +, e.g. eng+rus."; divider: false }
    }
    Section {
        id: share
        title: "Screen sharing"
        // screencast.remember: apps told "always share this" in the picker.
        readonly property var remembered: Settings.get("screencast.remember", {}) || {}
        SettingRow {
            visible: Object.keys(share.remembered).length === 0
            label: "No app shares without asking"; hint: "Tick “Always share this” in the share picker to skip it next time for that app."; divider: false
        }
        Repeater {
            model: Object.keys(share.remembered)
            delegate: SettingRow {
                required property string modelData
                readonly property var e: Settings.get("screencast.remember", {})[modelData] || {}
                label: ScreenShare.appName(modelData)
                hint: e.type === "monitor" ? "Shares the screen " + e.connector : "Shares a " + (e.appId || "") + " window"
                Capsule { label: "Forget"; onClicked: ScreenShare.forget(modelData) }
            }
        }
    }
    Section {
        title: "Colour picker"
        // picker.history: the last colours picked (Mod+Shift+P).
        SettingRow {
            label: "Recent colours"; hint: (Settings.get("picker.history", []) || []).length ? "Click one to copy it." : "None yet — Mod+Shift+P picks one from the screen."
            divider: false
            Repeater {
                model: Settings.get("picker.history", []) || []
                Rectangle {
                    required property string modelData
                    width: Tokens.islandHeight * 0.8; height: width; radius: width / 2; color: modelData
                    border.width: 1; border.color: Colors.alpha(Colors.text, 0.3)
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ColorPick.copy(modelData) }
                }
            }
            Capsule { visible: (Settings.get("picker.history", []) || []).length > 0; label: "Clear"; onClicked: Settings.set("picker.history", []) }
        }
    }
}
