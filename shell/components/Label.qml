import QtQuick
import qs.theme

// Text in the vitrum type: role picks the colour, numeric switches on tabular figures.
Text {
    property string role: "text"          // text | dim | accent | onAccent | danger
    property bool numeric: false
    property int size: Tokens.textSize

    font.family: numeric ? Tokens.fontText : Tokens.fontText
    font.pixelSize: size
    font.features: numeric ? { "tnum": 1 } : ({})
    color: role === "dim" ? Colors.textDim : role === "accent" ? Colors.accent
         : role === "onAccent" ? Colors.onAccent : role === "danger" ? Colors.danger : Colors.text
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    Behavior on color { enabled: Motion.enabled; ColorAnim {} }
}
