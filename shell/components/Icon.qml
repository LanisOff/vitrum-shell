import QtQuick
import qs.theme

// A UI icon by name (shell/data/icons.json).
Text {
    id: root
    property string name: "help"
    property int size: Tokens.iconSize
    property bool filled: false
    readonly property var _g: Icons.glyph(name)

    text: _g.text
    font.family: _g.font === "nerd" ? Tokens.fontNerd : Tokens.fontIcons
    font.pixelSize: size
    font.variableAxes: _g.font === "nerd" ? ({}) : { "FILL": filled ? 1 : 0, "wght": 400, "opsz": Math.max(20, Math.min(48, size)) }
    color: Colors.text
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    width: size; height: size
    Behavior on color { enabled: Motion.enabled; ColorAnim {} }
}
