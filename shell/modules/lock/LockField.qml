import QtQuick
import qs.services
import qs.theme
import qs.components

/*
 * The password capsule, of glass. The text itself is never drawn: each
 * character is a dot that pops in with a spring and shrinks away when erased.
 * While PAM checks, a light sweeps along the capsule.
 *
 * A wrong password: the glass and the dots blush red and the capsule shakes —
 * one damped swing, not a set of jerks — then the dots go out together and
 * the "Password" hint fades back in. Nothing overlaps on the way: the dots
 * stay until the shake is over, whatever the lock did with the password.
 */
LockGlass {
    id: field
    required property var lock

    width: Tokens.islandHeight * 11
    height: Tokens.islandHeight * 1.4
    radius: height / 2
    tint: Qt.tint(Qt.rgba(1, 1, 1, Colors.dark ? 0.07 : 0.16), Colors.alpha(Colors.danger, 0.38 * flash))
    outline: Qt.tint(Colors.alpha(Colors.text, 0.12), Colors.alpha(Colors.danger, 0.85 * flash))
    edgeLight: 0.5 + 0.3 * flash

    // ------------------------------------------------------- a refusal ---
    property real flash: 0
    property real swing: 0            // 0 → 1 over the shake
    property bool refusing: false
    property real dotsOpacity: 1
    readonly property real shake: Tokens.islandHeight * 0.42 * Math.sin(swing * Math.PI * 6) * Math.pow(1 - swing, 2)
    transform: Translate { x: field.shake }

    SequentialAnimation {
        id: refuse
        ScriptAction { script: { field.refusing = true; field.dotsOpacity = 1; } }
        ParallelAnimation {
            NumberAnimation { target: field; property: "swing"; from: 0; to: 1; duration: 520; easing.type: Easing.Linear }
            SequentialAnimation {
                NumberAnimation { target: field; property: "flash"; to: 1; duration: 90; easing.type: Easing.OutCubic }
                PauseAnimation { duration: 260 }
                NumberAnimation { target: field; property: "flash"; to: 0; duration: 520; easing.type: Easing.InOutCubic }
            }
            SequentialAnimation {
                PauseAnimation { duration: 380 }
                NumberAnimation { target: field; property: "dotsOpacity"; to: 0; duration: 160; easing.type: Easing.InCubic }
            }
        }
        ScriptAction { script: { field.refusing = false; field.dotsOpacity = 1; dots.sync(field.lock.password.length, false); } }
    }
    Connections {
        target: field.lock
        function onFailuresChanged() {
            if (field.lock.failures === 0) return;
            // Before the lock clears the password: the dots stay for the shake.
            if (Motion.enabled) { field.refusing = true; refuse.restart(); }
            else dots.sync(field.lock.password.length, false);
        }
    }

    // ------------------------------------------------- the checking sweep ---
    Item {
        anchors.fill: parent
        clip: true
        Rectangle {
            id: sweep
            visible: field.lock.busy && Motion.enabled
            width: field.width * 0.35; height: field.height
            property real p: 0
            x: -width + p * (field.width + width)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: Colors.alpha(Colors.accent, 0.28) }
                GradientStop { position: 1; color: "transparent" }
            }
            NumberAnimation on p { running: sweep.visible; loops: Animation.Infinite; from: 0; to: 1; duration: Motion.emphasized * 3; easing.type: Easing.InOutQuad }
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding * 1.5; anchors.rightMargin: Tokens.padding
        spacing: Tokens.gap
        Icon { id: lockIcon; name: "lock"; color: Qt.tint(Colors.textDim, Colors.alpha(Colors.danger, field.flash)); anchors.verticalCenter: parent.verticalCenter }
        Item {
            width: parent.width - lockIcon.width - layoutChip.width - 2 * Tokens.gap
            height: parent.height
            TextInput {
                id: input
                anchors.fill: parent
                // Typed into, never shown: the dots below are the echo.
                color: "transparent"
                selectionColor: "transparent"
                selectedTextColor: "transparent"
                cursorVisible: false
                cursorDelegate: Item {}
                echoMode: TextInput.Password
                font.pixelSize: Tokens.textLarge
                verticalAlignment: TextInput.AlignVCenter
                focus: true
                enabled: !field.lock.busy && !field.lock.leaving
                onTextChanged: if (field.lock.password !== text) field.lock.password = text
                onAccepted: field.lock.submit()
                Keys.onPressed: event => { field.lock.poke(); event.accepted = false; }
                Keys.onEscapePressed: text = ""
            }
            // The password is the lock's: typed here, or cleared by it after a failure.
            Connections {
                target: field.lock
                function onPasswordChanged() {
                    if (input.text !== field.lock.password) input.text = field.lock.password;
                    if (!field.refusing) dots.sync(field.lock.password.length, true);
                }
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                opacity: dotModel.count === 0 && !field.refusing ? 1 : 0
                Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.standard } }
                text: field.lock.busy ? "Checking…" : "Password"
                role: "dim"
                size: Tokens.textLarge
            }
            ListView {
                id: dots
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: Tokens.textLarge
                orientation: ListView.Horizontal
                interactive: false
                spacing: Tokens.gap * 0.7
                clip: true
                opacity: field.dotsOpacity
                model: ListModel { id: dotModel }
                property bool animated: true
                /// To n dots; animated: each one pops or shrinks (typing), else all at once.
                function sync(n, anim) {
                    animated = anim;
                    if (!anim && n === 0) dotModel.clear();
                    while (dotModel.count < n) dotModel.append({});
                    while (dotModel.count > n) dotModel.remove(dotModel.count - 1);
                    animated = true;
                    positionViewAtEnd();
                }
                delegate: Rectangle {
                    width: Tokens.textLarge * 0.55; height: width; radius: width / 2
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                    color: Qt.tint(Colors.text, Colors.alpha(Colors.danger, field.flash))
                }
                add: Transition {
                    enabled: Motion.enabled && dots.animated
                    NumberAnimation { property: "scale"; from: 0; to: 1; duration: Motion.standard; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.fast }
                }
                remove: Transition {
                    enabled: Motion.enabled && dots.animated
                    NumberAnimation { property: "scale"; to: 0; duration: Motion.fast; easing.type: Easing.InCubic }
                    NumberAnimation { property: "opacity"; to: 0; duration: Motion.fast }
                }
            }
        }
        // Typing the password in the wrong layout is the classic lock-screen trap.
        Rectangle {
            id: layoutChip
            visible: Niri.keyboardShort.length > 0
            anchors.verticalCenter: parent.verticalCenter
            width: visible ? Tokens.iconSize * 2 : 0; height: Tokens.iconSize * 1.3; radius: height / 2
            color: Colors.alpha(Colors.accent, 0.25)
            Label { anchors.centerIn: parent; text: Niri.keyboardShort; size: Tokens.textSmall; font.weight: Font.DemiBold }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Niri.switchLayout(true) }
        }
    }
}
