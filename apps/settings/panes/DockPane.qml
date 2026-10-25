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
        SettingToggle { key: "dock.intellihide"; needs: "dock.enabled"; label: "Hide when a window overlaps it"; hint: "It comes back when you move to the bottom edge." }
        SettingToggle { key: "dock.magnify"; needs: "dock.enabled"; label: "Magnify icons under the pointer"; hint: "The neighbours grow a little too, and the row spreads." }
        SettingSlider { key: "dock.magnifyAmount"; enabled: Settings.get("dock.enabled", false) === true && Settings.get("dock.magnify", false) === true; label: "Magnification"; from: 1.1; to: 2; step: 0.05; unit: "×" }
        SettingSlider { key: "dock.iconSize"; needs: "dock.enabled"; label: "Icon size"; from: 28; to: 72; step: 1; unit: " px"; divider: false }
    }
    Section {
        title: "Pinned"
        SettingList { key: "dock.pinned"; label: "Apps"; hint: "Application ids (as niri reports them, e.g. org.kde.dolphin). Right-click an icon in the Dock to pin or unpin it." }
    }
}
