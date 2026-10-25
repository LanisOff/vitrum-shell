import QtQuick
import qs.theme

// A weather symbol in vitrum's own icon language: the Phosphor Light weather
// line icons (sun, cloud-sun, cloud-rain…), in the accent — the same thin line
// icons as the bar and the menus. `kind` takes Weather.symbol()'s names; `day`
// picks the night variants (a moon for a clear night, cloud-moon for a partly
// cloudy one).
Icon {
    id: root
    property string kind: "weather-clear"
    property bool day: true
    name: day ? kind
        : kind === "weather-clear" ? "weather-night"
        : kind === "weather-partly" ? "weather-partly-night"
        : kind
    filled: false
    color: Colors.accent
}
