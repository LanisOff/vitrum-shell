import QtQuick
import qs.theme
import qs.components

// A text field: a placeholder while empty, a password mode with an eye to
// show what was typed. `text` is the value; accepted() on Enter.
// A glass field (radius Tokens.radiusButton) in the group's material; focus
// draws an accent ring, an invalid value a danger one.
Surface {
    id: f
    property alias text: input.text
    property string placeholder: ""
    property bool password: false
    property bool revealed: false
    property bool mono: false
    property bool invalid: false
    readonly property bool focused: input.activeFocus
    signal accepted()
    function takeFocus() { input.forceActiveFocus(); }
    implicitWidth: Tokens.islandHeight * 8
    implicitHeight: Tokens.islandHeight * 1.1
    group: "panels"; level: 1
    radius: Tokens.radiusButton
    border.width: input.activeFocus || invalid ? 2 : Tokens.hairline
    border.color: invalid ? Colors.danger : input.activeFocus ? Colors.accent : Materials.border(group)
    TextInput {
        id: input
        anchors { left: parent.left; right: eye.left; leftMargin: Tokens.gap; rightMargin: Tokens.gap / 2; verticalCenter: parent.verticalCenter }
        font.family: f.mono ? Tokens.fontMono : Tokens.fontText; font.pixelSize: Tokens.textSize
        color: Colors.text; selectionColor: Colors.accent; selectByMouse: true
        echoMode: f.password && !f.revealed ? TextInput.Password : TextInput.Normal
        passwordCharacter: "•"
        clip: true
        onAccepted: f.accepted()
        Label { visible: !input.text; text: f.placeholder; role: "dim"; anchors.verticalCenter: parent.verticalCenter; width: input.width }
    }
    Icon {
        id: eye
        visible: f.password
        width: visible ? Tokens.iconSize : 0
        anchors { right: parent.right; rightMargin: visible ? Tokens.gap : 0; verticalCenter: parent.verticalCenter }
        name: f.revealed ? "visibility-off" : "visibility"
        color: Colors.textDim
        size: Tokens.iconSize * 0.9
        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: f.revealed = !f.revealed }
    }
}
