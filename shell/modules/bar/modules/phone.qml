import QtQuick
import ".."
import qs.services
import qs.theme
// The phone (KDE Connect) while it is in reach, with its battery.
StatusIcon {
    shown: Phone.connected
    icon: "phone"
    label: Phone.phone && Phone.phone.charge >= 0 ? Phone.phone.charge + "%" : ""
    tint: Phone.phone && Phone.phone.charge >= 0 && Phone.phone.charge <= 15 && !Phone.phone.charging ? Colors.danger : Colors.text
}
