import QtQuick
import qs.theme

// A weather symbol in vitrum's own icon language: the Material Symbols
// outline, in the accent — the same line icons as the bar and the menus.
// `kind` takes Weather.symbol()'s names; `day` picks the night variants.
Icon {
    id: root
    property string kind: "weather-clear"
    property bool day: true
    name: !day && (kind === "weather-clear" || kind === "weather-partly") ? "weather-night" : kind
    filled: false
    color: Colors.accent
}
