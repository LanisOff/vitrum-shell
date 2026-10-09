import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components
import qs.common

Page {
    title: "Navigation"
    Section {
        title: "Launcher"
        SettingText { key: "launcher.web"; label: "Web search"; hint: "%s is replaced by what you typed. Google by default."; fieldWidth: Tokens.islandHeight * 14; divider: false }
    }
    Section {
        title: "Clipboard history"
        SettingSlider { key: "clipboard.images"; label: "Pictures kept"; from: 0; to: 2000; step: 50; hint: "Text is kept for good, until you clear the history (Spotlight's Clipboard). Older pictures go first."; divider: false }
    }
    Section {
        title: "Alt+Tab"
        SettingSlider { key: "switcher.quickTapMs"; label: "Quick tap switches after"; from: 300; to: 2000; step: 50; unit: " ms"; hint: "With Alt held and nothing pressed, the switcher picks the highlighted window after this long."; divider: false }
    }
    Section {
        title: "Overview"
        SettingToggle { key: "overview.overlay"; label: "Workspace list and window search over the overview"; divider: false }
    }
    Section {
        title: "Hot corners"
        SettingToggle { key: "corners.enabled"; label: "Hot corners"; hint: "Rest the pointer in a corner. They never fire over a fullscreen window." }
        SettingChoice { key: "corners.topLeft"; label: "Top left"; names: ({ none: "Nothing", overview: "Overview", desktop: "Show the desktop", notifications: "Notifications", launcher: "Launcher", control: "Control Centre" }) }
        SettingChoice { key: "corners.topRight"; label: "Top right"; names: ({ none: "Nothing", overview: "Overview", desktop: "Show the desktop", notifications: "Notifications", launcher: "Launcher", control: "Control Centre" }) }
        SettingChoice { key: "corners.bottomLeft"; label: "Bottom left"; names: ({ none: "Nothing", overview: "Overview", desktop: "Show the desktop", notifications: "Notifications", launcher: "Launcher", control: "Control Centre" }) }
        SettingChoice { key: "corners.bottomRight"; label: "Bottom right"; names: ({ none: "Nothing", overview: "Overview", desktop: "Show the desktop", notifications: "Notifications", launcher: "Launcher", control: "Control Centre" }) }
        SettingSlider { key: "corners.delay"; label: "Wait before acting"; from: 0; to: 600; step: 50; unit: " ms"; divider: false }
    }
}
