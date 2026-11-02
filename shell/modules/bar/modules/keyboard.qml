import QtQuick
import qs.services
import qs.theme
import qs.components
import ".."

// The keyboard layout or input method (EN/RU/JP…, or its full name with
// bar.modules.keyboard.long); click switches to the next one.
BarModule {
    id: root
    shown: Layouts.available && Layouts.names.length > 1
    implicitWidth: label.implicitWidth + Tokens.gap
    Label { id: label; anchors.centerIn: parent; text: Settings.get("bar.modules.keyboard.long", false) ? Layouts.current : Layouts.short; font.weight: Font.DemiBold; size: Tokens.textSmall }
    onClicked: Layouts.next(true)
}
