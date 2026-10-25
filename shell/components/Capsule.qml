import QtQuick
import qs.theme

// deprecated alias, kept for user widgets: use GlassButton. The old API with
// the new look: `active` is a primary (tinted) button, `color` the colour
// its tint starts from.
GlassButton {
    property bool active: false
    property color color: Colors.accent
    primary: active
    tint: color
}
