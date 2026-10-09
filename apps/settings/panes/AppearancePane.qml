import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components
import qs.common

Page {
    title: "Appearance"
    subtitle: "Light and dark, colours and density. Everything applies at once."
    Section {
        title: "Scheme"
        SettingChoice { key: "scheme.mode"; names: ({ auto: "Automatic", light: "Light", dark: "Dark" }); hint: "Automatic follows sunrise and sunset where you are (Date, time & weather), otherwise the times below." }
        SettingText { key: "scheme.light"; label: "Light from"; placeholder: "07:00"; fieldWidth: Tokens.islandHeight * 3 }
        SettingText { key: "scheme.dark"; label: "Dark from"; placeholder: "19:30"; fieldWidth: Tokens.islandHeight * 3; divider: false }
    }
    Section {
        title: "Colours"
        SettingChoice { key: "palette.source"; names: ({ wallpaper: "From the wallpaper", preset: "Preset" }) }
        SettingChoice { key: "palette.preset"; hint: "Used when the source is a preset, or when the wallpaper cannot be read." }
        SettingColor { key: "palette.accent"; label: "Accent"; hint: "Overrides the palette's accent; × keeps the palette's own."; divider: false }
    }
    Section {
        title: "Density"
        SettingChoice { key: "density"; hint: "Sizes of bars, panels, gaps and text."; divider: false }
    }
    Section {
        title: "Other apps"
        SettingToggle { key: "toolkits.kde"; label: "Colour KDE apps"; hint: "Dolphin, Kate, Okular… take the palette through kdeglobals. Off leaves kdeglobals to you (Plasma, your own scheme)." }
        SettingToggle { key: "toolkits.gtk"; label: "Colour GTK apps"; hint: "GTK 3 and 4 apps (pavucontrol, file dialogs…) take the palette through adw-gtk3. Off leaves your GTK theme and files alone."; divider: false }
    }
}
