import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components

// The polkit agent's prompt: what wants it, whose password. Centred like the
// lock screen: the lock, the question, one field, two buttons. A wrong
// password shakes the field and says so under it.
DialogFrame {
    id: root
    readonly property var flow: Polkit.flow
    open: Polkit.active && flow !== null && screen.name === (Niri.focusedOutput || Quickshell.screens[0].name)
    onDismissed: if (flow) flow.cancelAuthenticationRequest()
    onOpenChanged: if (open) { pass.text = ""; pass.forceActiveFocus(); }

    readonly property string who: flow && flow.selectedIdentity ? flow.selectedIdentity.displayName : ""
    // polkit quotes with backticks (`/usr/bin/true'); typographic quotes read better.
    readonly property string message: (flow ? flow.message : "").replace(/`([^']*)'/g, "“$1”")
    readonly property bool failed: !!flow && flow.supplementaryIsError && (flow.supplementaryMessage || "").length > 0
    onFailedChanged: if (failed) { pass.text = ""; shake.restart(); }
    function submit() { if (flow && pass.text.length) flow.submit(pass.text); }

    readonly property real w: Tokens.islandHeight * 13.5
    Column {
        width: root.w
        spacing: Tokens.gap * 1.2

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Tokens.islandHeight * 1.7; height: width; radius: width / 2
            color: Colors.alpha(Colors.accent, 0.16)
            Icon { anchors.centerIn: parent; name: "lock"; size: Tokens.iconSize * 1.7; color: Colors.accent }
        }
        Label {
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: "Authentication required"; size: Tokens.textLarge; font.weight: Font.DemiBold
        }
        Label {
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: root.message; role: "dim"; wrapMode: Text.WordWrap
        }
        Item { width: 1; height: Tokens.gap * 0.4 }

        // The field: the password, the keyboard layout beside it.
        Surface {
            id: field
            width: parent.width
            height: Tokens.islandHeight * 1.35
            radius: height / 2
            group: "dialogs"; level: 1
            border.width: pass.activeFocus ? 2 : Tokens.hairline
            border.color: root.failed ? Colors.danger : pass.activeFocus ? Colors.alpha(Colors.accent, 0.8) : Materials.border("dialogs")
            transform: Translate { id: nudge }
            SequentialAnimation {
                id: shake
                NumberAnimation { target: nudge; property: "x"; to: -8; duration: 50 }
                NumberAnimation { target: nudge; property: "x"; to: 8; duration: 70 }
                NumberAnimation { target: nudge; property: "x"; to: -5; duration: 60 }
                NumberAnimation { target: nudge; property: "x"; to: 0; duration: 60 }
            }
            TextInput {
                id: pass
                anchors.left: parent.left; anchors.leftMargin: Tokens.padding * 1.2
                anchors.right: layoutChip.left; anchors.rightMargin: Tokens.gap
                anchors.verticalCenter: parent.verticalCenter
                echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                passwordCharacter: "•"
                font.family: Tokens.fontText; font.pixelSize: Tokens.textSize
                color: Colors.text
                clip: true
                onAccepted: root.submit()
                Label {
                    visible: pass.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.who ? "Password for " + root.who : "Password"
                    role: "dim"
                }
            }
            Rectangle {
                id: layoutChip
                visible: Niri.keyboardShort.length > 0
                anchors.right: parent.right; anchors.rightMargin: Tokens.gap
                anchors.verticalCenter: parent.verticalCenter
                width: visible ? Tokens.iconSize * 2 : 0; height: Tokens.iconSize * 1.3; radius: height / 2
                color: Colors.alpha(Colors.accent, 0.2)
                Label { anchors.centerIn: parent; text: Niri.keyboardShort; size: Tokens.textSmall; font.weight: Font.DemiBold }
            }
        }
        Label {
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            visible: text.length > 0
            text: root.flow ? root.flow.supplementaryMessage : ""
            role: root.failed ? "danger" : "dim"
            size: Tokens.textSmall
            wrapMode: Text.WordWrap
        }

        // Two buttons, sharing the width.
        Row {
            width: parent.width
            spacing: Tokens.gap
            Repeater {
                model: [{ text: "Cancel", main: false }, { text: "Authenticate", main: true }]
                delegate: Rectangle {
                    required property var modelData
                    width: (root.w - Tokens.gap) / 2
                    height: Tokens.islandHeight * 1.2
                    radius: height / 2
                    color: modelData.main ? (btn.containsMouse ? Qt.lighter(Colors.accent, 1.08) : Colors.accent)
                                          : Colors.alpha(Colors.text, btn.containsMouse ? 0.12 : 0.07)
                    opacity: modelData.main && pass.text.length === 0 ? 0.55 : 1
                    Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
                    Label { anchors.centerIn: parent; text: parent.modelData.text; role: parent.modelData.main ? "onAccent" : "text"; font.weight: Font.DemiBold }
                    MouseArea {
                        id: btn
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: parent.modelData.main ? root.submit() : root.dismissed()
                    }
                }
            }
        }
    }
}
