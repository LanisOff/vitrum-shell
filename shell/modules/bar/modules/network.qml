import QtQuick
import ".."
import qs.theme
import qs.services
// Wi-Fi shows its strength in the glyph: low, medium or high.
StatusIcon {
    icon: Network.kind === "wired" ? "ethernet" : Network.kind !== "wifi" ? "network-off" : Network.strength > 0.66 ? "wifi-high" : Network.strength > 0.33 ? "wifi-medium" : "wifi-low"
    tint: Network.online ? Colors.text : Colors.textDim
}
