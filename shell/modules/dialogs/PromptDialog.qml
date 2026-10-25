import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components

// A question from the system (services/Prompt.qml): an icon, the question, a
// code to compare or a field to fill, two buttons. Shown on the focused screen.
DialogFrame {
    id: root
    readonly property var q: Prompt.current
    open: q !== null && !Polkit.active && screen.name === (Niri.focusedOutput || Quickshell.screens[0].name)
    onDismissed: Prompt.answer(false, "")
    focusItem: q && q.field ? input : enterCatcher
    property int lastToken: -1
    // The field (or, without one, the item that takes Enter) gets the keyboard
    // once the dialog is open — after DialogFrame's own item has taken it.
    function takeKeyboard() { Qt.callLater(() => { if (root.open) (root.q && root.q.field ? input : enterCatcher).forceActiveFocus(); }); }
    onOpenChanged: if (open) takeKeyboard()
    // A new question: the field starts empty.
    onQChanged: if (q && q.token !== lastToken) { lastToken = q.token; input.text = ""; input.revealed = false; takeKeyboard(); }
    function submit() {
        if (!q) return;
        if (q.field && !input.text.length) return;
        Prompt.answer(true, input.text);
    }

    readonly property real w: Tokens.islandHeight * 13.5
    Column {
        width: root.w
        spacing: Tokens.gap * 1.2

        // A plain line icon in the second hue, where the tonal circle was.
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Tokens.islandHeight * 1.7; height: width
            Icon { anchors.centerIn: parent; name: root.q ? root.q.icon : "help"; size: Tokens.iconSize * 1.7; color: Colors.accent2 }
        }
        Label {
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: root.q ? root.q.title : ""; size: Tokens.textLarge; font.weight: Font.DemiBold
            wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        Label {
            visible: text.length > 0
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: root.q ? root.q.message : ""; role: "dim"; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        // A code to compare with the one on the other device.
        Label {
            visible: !!root.q && root.q.code.length > 0
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: root.q ? root.q.code.replace(/(\d{3})(\d{3})/, "$1 $2") : ""
            font.family: Tokens.fontMono; size: Tokens.textTitle * 1.4; font.weight: Font.DemiBold; font.letterSpacing: 4
            numeric: true
        }
        Surface {
            visible: !!root.q && root.q.field.length > 0
            width: parent.width
            height: Tokens.islandHeight * 1.35
            radius: Tokens.radiusButton
            group: "dialogs"; level: 1
            border.width: input.activeFocus ? 2 : Tokens.hairline
            border.color: input.activeFocus ? Colors.alpha(Colors.accent, 0.8) : Materials.border("dialogs")
            TextInput {
                id: input
                anchors { left: parent.left; right: eye.left; leftMargin: Tokens.padding * 1.2; rightMargin: Tokens.gap; verticalCenter: parent.verticalCenter }
                property bool revealed: false
                echoMode: root.q && root.q.field === "password" && !revealed ? TextInput.Password : TextInput.Normal
                passwordCharacter: "•"
                inputMethodHints: root.q && root.q.field === "number" ? Qt.ImhDigitsOnly : Qt.ImhNone
                validator: RegularExpressionValidator { regularExpression: root.q && root.q.field === "number" ? /\d{0,6}/ : /.*/ }
                font.family: Tokens.fontText; font.pixelSize: Tokens.textSize
                color: Colors.text
                clip: true
                onAccepted: root.submit()
                Label { visible: input.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: root.q ? root.q.placeholder : ""; role: "dim" }
            }
            Icon {
                id: eye
                visible: !!root.q && root.q.field === "password"
                width: visible ? Tokens.iconSize : 0
                anchors { right: parent.right; rightMargin: Tokens.padding; verticalCenter: parent.verticalCenter }
                name: input.revealed ? "visibility-off" : "visibility"; color: Colors.textDim
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: input.revealed = !input.revealed }
            }
        }
        Row {
            width: parent.width
            spacing: Tokens.gap
            Repeater {
                model: !root.q ? [] : root.q.info ? [{ text: root.q.okText, main: true }]
                                  : [{ text: root.q.cancelText, main: false }, { text: root.q.okText, main: true }]
                // The answer is tinted, the other one clear glass.
                delegate: GlassButton {
                    required property var modelData
                    width: root.q && root.q.info ? root.w : (root.w - Tokens.gap) / 2
                    height: Tokens.islandHeight * 1.2
                    group: "dialogs"
                    label: modelData.text
                    primary: modelData.main
                    opacity: modelData.main && root.q && root.q.field && input.text.length === 0 ? 0.55 : 1
                    Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
                    onClicked: modelData.main ? root.submit() : root.dismissed()
                }
            }
        }
    }
    // Enter answers yes when there is no field to type into.
    Item { id: enterCatcher; Keys.onReturnPressed: root.submit(); Keys.onEnterPressed: root.submit(); Keys.onEscapePressed: root.dismissed() }
}
