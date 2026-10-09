import QtQuick
import ".."
import qs.theme
import qs.services
StatusIcon {
    icon: Network.kind === "wired" ? "ethernet" : Network.kind === "wifi" ? "wifi" : "network-off"
    tint: Network.online ? Colors.text : Colors.textDim
    filled: Network.kind === "wifi" && Network.strength > 0.66
}
