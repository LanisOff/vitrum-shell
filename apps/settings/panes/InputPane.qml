import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import qs.common
import "../lib/pointer.js" as Pointer

Page {
    id: page
    title: "Mouse & touchpad"
    subtitle: "Applied at once. A mouse or touchpad block in ~/.config/vitrum/niri/overrides.kdl replaces these."
    property var over: ({ mouse: false, touchpad: false })
    property bool hasTouchpad: false
    FileView {
        path: Quickshell.env("HOME") + "/.config/vitrum/niri/overrides.kdl"
        watchChanges: true
        onLoaded: page.over = Pointer.overridden(text())
        onFileChanged: reload()
    }
    Process {
        running: true
        command: ["sh", "-c", "cat /sys/class/input/*/device/name 2>/dev/null | grep -qi touchpad && echo yes"]
        stdout: StdioCollector { onStreamFinished: page.hasTouchpad = text.trim() === "yes" }
    }
    component Notice: SettingRow {
        label: "Set in overrides.kdl"
        hint: "These controls have no effect while that block is there."
        divider: false
    }
    Section {
        title: "Mouse"
        Notice { visible: page.over.mouse }
        SettingSlider { key: "input.mouse.speed"; label: "Speed"; from: -1; to: 1; step: 0.05 }
        SettingToggle { key: "input.mouse.accel"; label: "Acceleration"; hint: "Off: the pointer moves exactly with the mouse, best for games." }
        SettingSlider { key: "input.mouse.scroll"; label: "Scroll speed"; from: 0.25; to: 3; step: 0.05; unit: "×" }
        SettingToggle { key: "input.mouse.natural"; label: "Natural scrolling"; hint: "Content follows the wheel, like on a touchpad."; divider: false }
    }
    Section {
        title: "Touchpad"
        visible: page.hasTouchpad
        Notice { visible: page.over.touchpad }
        SettingSlider { key: "input.touchpad.speed"; label: "Speed"; from: -1; to: 1; step: 0.05 }
        SettingToggle { key: "input.touchpad.natural"; label: "Natural scrolling" }
        SettingToggle { key: "input.touchpad.tap"; label: "Tap to click"; divider: false }
    }
}
