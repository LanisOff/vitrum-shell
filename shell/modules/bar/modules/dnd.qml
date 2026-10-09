import QtQuick
import ".."
import qs.services
import qs.theme
StatusIcon {
    shown: Notifs.doNotDisturb
    icon: "dnd"
    tint: Colors.accent
    filled: true
}
