import QtQuick
import qs.theme

// A shape in a material: group decides solid/frosted/glass, level 0..2 how raised.
Rectangle {
    property string group: "panels"
    property int level: 0
    property bool outlined: true

    radius: Tokens.radiusPanel
    color: Materials.fill(group, level)
    border.width: outlined ? Tokens.hairline : 0
    border.color: Materials.border(group)
    Behavior on color { enabled: Motion.enabled; ColorAnim {} }
}
