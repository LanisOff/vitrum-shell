import QtQuick
import ".."
import qs.services
import qs.theme
// A padlock while a VPN carries the traffic; where to, in the tooltip of the Control Centre chip.
StatusIcon {
    shown: Vpn.active
    icon: "vpn"
    tint: Colors.accent
    filled: true
}
