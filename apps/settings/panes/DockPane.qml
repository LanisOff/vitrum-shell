import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components
import qs.common

Page {
    title: "Dock"
    Section {
        SettingToggle { key: "dock.enabled"; label: "Show the Dock" }
        SettingToggle { key: "dock.intellihide"; label: "Hide when a window overlaps it"; hint: "It comes back when you move to the bottom edge." }
        SettingToggle { key: "dock.magnify"; label: "Magnify icons under the pointer"; hint: "The neighbours grow a little too, and the row spreads." }
        SettingSlider { key: "dock.magnifyAmount"; label: "Magnification"; from: 1.1; to: 2; step: 0.05; unit: "×" }
        SettingToggle { key: "dock.stacks"; label: "Stacks" }
        SettingSlider { key: "dock.iconSize"; label: "Icon size"; from: 28; to: 72; step: 1; unit: " px"; divider: false }
    }
    Section {
        title: "Pinned"
        SettingList { key: "dock.pinned"; label: "Apps"; hint: "Application ids (as niri reports them, e.g. org.kde.dolphin). Right-click an icon in the Dock to pin or unpin it." }
    }
}
