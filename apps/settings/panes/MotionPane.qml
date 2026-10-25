import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components
import qs.common

Page {
    title: "Motion"
    Section {
        title: "Motion"
        SettingSlider { key: "motion.speed"; label: "Animation speed"; from: 0.5; to: 2; step: 0.05; unit: "×"; hint: "Springs and fades everywhere, niri's included." }
        SettingToggle { key: "motion.reduce"; label: "Reduce motion"; hint: "No animation at all, fades included: everything changes at once. niri's too."; divider: false }
    }
}
