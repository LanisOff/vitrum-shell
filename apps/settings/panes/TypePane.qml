import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components
import qs.common

Page {
    title: "Fonts & icons"
    Section {
        title: "Fonts"
        SettingChoice { key: "fonts.preset"; names: ({ sans: "Sans", mono: "Mono" }); hint: "Mono uses the Nerd Font for text and icons — a terminal look." }
        SettingSlider { key: "fonts.scale"; label: "Text size"; from: 0.85; to: 1.3; step: 0.05; unit: "×"; hint: "Text in the shell and these apps. Bars and panels keep their size (Appearance → Density)." }
        SettingText { key: "fonts.sans"; label: "Sans font" }
        SettingText { key: "fonts.mono"; label: "Mono font" }
        SettingText { key: "fonts.nerd"; label: "Nerd Font"; divider: false }
    }
    Section {
        title: "Icons and cursor"
        SettingText { key: "icons.theme"; label: "Icon theme"; hint: "For applications (Papirus-Dark, Papirus-Light, …)." }
        SettingToggle { key: "icons.backplates"; label: "Backplates behind app icons" }
        SettingText { key: "cursor.theme"; label: "Cursor theme"; divider: false }
    }
}
