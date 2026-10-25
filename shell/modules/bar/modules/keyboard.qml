import QtQuick
import qs.services
import qs.theme
import qs.components
import ".."

// The keyboard layout (EN/RU…, or its full name with bar.modules.keyboard.long);
// click switches to the next one.
BarModule {
    id: root
    shown: Niri.available && Niri.keyboardLayouts.length > 1
    implicitWidth: label.implicitWidth + Tokens.gap
    Label { id: label; anchors.centerIn: parent; text: Settings.get("bar.modules.keyboard.long", false) ? Niri.keyboardLayout : Niri.keyboardShort; font.weight: Font.DemiBold; size: Tokens.textSmall }
    onClicked: Niri.switchLayout(true)
}
