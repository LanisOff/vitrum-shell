import QtQuick
import qs.theme

// A UI icon by name (shell/data/icons.json): a Phosphor Light line icon, or
// Phosphor Fill when `filled` (the player's solid icons, and users' own
// widgets), or a Nerd Font glyph in the mono font preset.
Text {
    id: root
    property string name: "help"
    property int size: Tokens.iconSize
    property bool filled: false
    readonly property var _g: Icons.glyph(name)

    text: _g.text
    font.family: _g.font === "nerd" ? Tokens.fontNerd : filled ? Tokens.fontIconsFill : Tokens.fontIcons
    font.pixelSize: size
    color: Colors.text
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    width: size; height: size
    Behavior on color { enabled: Motion.enabled; ColorAnim {} }
}
