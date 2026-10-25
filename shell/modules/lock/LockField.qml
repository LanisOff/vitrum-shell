import QtQuick
import QtQuick.Effects
import qs.services
import qs.theme
import qs.components

/*
 * The password field, of glass (a rounded rectangle, Tokens.radiusTile). The
 * text itself is never drawn: each character is a dot that grows in, damped,
 * and shrinks away when erased.
 *
 * Dichroic: once there is something typed the field lights up gently with the
 * tint (ShellTint), a little more with each character up to eight. While PAM
 * checks, a light that turns from the accent to accent2 sweeps along it. A
 * good password sweeps the tint once more as the lock dissolves (LockView
 * blooms the flash out of here).
 *
 * A wrong password: the glass takes the danger tint (Colors.danger and its
 * pair), the dots blush red and the field shakes — one damped swing, not a
 * set of jerks — then the dots go out together and the "Password" hint fades
 * back in. Nothing overlaps on the way: the dots stay until the shake is
 * over, whatever the lock did with the password.
 *
 * Caps Lock on: a small line icon at the right end (lock.capsLock).
 */
LockGlass {
    id: field
    required property var lock

    width: Tokens.islandHeight * 11
    height: Tokens.islandHeight * 1.4
    radius: Tokens.radiusTile
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
        ScriptAction { script: { field.refusing = true; field.dotsOpacity = 1; dangerTint.sweep(); } }
        ParallelAnimation {
            NumberAnimation { target: field; property: "swing"; from: 0; to: 1; duration: 520; easing.type: Easing.Linear }
            SequentialAnimation {
                NumberAnimation { target: field; property: "flash"; to: 1; duration: 120; easing.type: Easing.OutCubic }
                PauseAnimation { duration: 300 }
                NumberAnimation { target: field; property: "flash"; to: 0; duration: 560; easing.type: Easing.InOutCubic }
            }
            SequentialAnimation {
                PauseAnimation { duration: 380 }
                NumberAnimation { target: field; property: "dotsOpacity"; to: 0; duration: 160; easing.type: Easing.InCubic }
            }
        }
        // The dots go while they are invisible: the ListView runs its remove
        // transition after sync() returns, so lighting them first showed the
        // old dots shrinking over the "Password" hint as it came back.
        ScriptAction { script: dots.sync(field.lock.password.length, false) }
        PauseAnimation { duration: Motion.fast + 40 }
        ScriptAction { script: { dots.sync(field.lock.password.length, false); field.refusing = false; field.dotsOpacity = 1; } }
    }
    Connections {
        target: field.lock
        function onFailuresChanged() {
            if (field.lock.failures === 0) return;
            // Before the lock clears the password: the dots stay for the shake.
            if (Motion.enabled) { field.refusing = true; refuse.restart(); }
            else dots.sync(field.lock.password.length, false);
        }
        function onLeavingChanged() { if (field.lock.leaving) typingTint.sweep(); }
    }

    // ------------------------------------------------------- the tints ---
    /// Something typed (or being checked, or let in): the dichroic tint is on.
    readonly property bool lit: (field.lock.password.length > 0 || field.lock.busy || field.lock.leaving) && !field.refusing
    // Gently: paler than a tile that is on, and growing with the first few characters.
    Item {
        anchors.fill: parent
        opacity: field.lock.leaving ? 1 : 0.6 + 0.4 * Math.min(1, field.lock.password.length / 8)
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.emphasized } }
        ShellTint {
            id: typingTint
            anchors.fill: parent
            radius: field.radius
            group: "lock"
            active: field.lit
            alphaStart: Colors.dark ? 0.44 : 0.28
            alphaMiddle: Colors.dark ? 0.36 : 0.22
            alphaEnd: Colors.dark ? 0.42 : 0.26
        }
    }
    // A refusal: the danger tint (Colors.danger → its pair), swept once, as long as the flash.
    Item {
        anchors.fill: parent
        opacity: field.flash
        visible: opacity > 0
        ShellTint {
            id: dangerTint
            anchors.fill: parent
            radius: field.radius
            group: "lock"
            tint: Colors.danger
        }
    }

    // ------------------------------------------------- the checking sweep ---
    // Cut to the field's own shape: `clip` only ever cuts square, so the
    // light would run on past the rounded corners as a bright rectangle. The
    // mask is the glass's rounded rectangle (same bounds, same radius).
    Rectangle {
        id: sweepMask
        anchors.fill: parent
        radius: field.radius
        visible: false
        layer.enabled: true
        layer.smooth: true
    }
    Item {
        anchors.fill: parent
        visible: field.lock.busy && Motion.enabled
        layer.enabled: visible
        layer.effect: MultiEffect { maskEnabled: true; maskSource: sweepMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
        Rectangle {
            id: sweep
            width: field.width * 0.45; height: field.height
            property real p: 0
            x: -width + p * (field.width + width)
            // Dichroic: the light turns from the accent to accent2 as it passes.
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.35; color: Colors.alpha(Colors.accent, 0.38) }
                GradientStop { position: 0.65; color: Colors.alpha(Colors.accent2, 0.42) }
                GradientStop { position: 1; color: "transparent" }
            }
            NumberAnimation on p { running: sweep.visible; loops: Animation.Infinite; from: 0; to: 1; duration: Motion.emphasized * 3; easing.type: Easing.InOutQuad }
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding * 1.5; anchors.rightMargin: Tokens.padding * 1.2
        spacing: Tokens.gap
        Icon { id: lockIcon; name: "lock"; color: Qt.tint(Colors.textDim, Colors.alpha(Colors.danger, field.flash)); anchors.verticalCenter: parent.verticalCenter }
        Item {
            width: parent.width - lockIcon.width - caps.width - 2 * Tokens.gap
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
                Keys.onPressed: event => {
                    field.lock.poke();
                    if (event.key === Qt.Key_CapsLock) field.lock.checkCaps();
                    event.accepted = false;
                }
                Keys.onReleased: event => { if (event.key === Qt.Key_CapsLock) field.lock.checkCaps(); event.accepted = false; }
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
                /// To n dots; animated: each one grows or shrinks (typing), else all at once.
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
                    NumberAnimation { property: "scale"; from: 0; to: 1; duration: Motion.standard; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.fast }
                }
                remove: Transition {
                    enabled: Motion.enabled && dots.animated
                    NumberAnimation { property: "scale"; to: 0; duration: Motion.fast; easing.type: Easing.InCubic }
                    NumberAnimation { property: "opacity"; to: 0; duration: Motion.fast }
                }
            }
        }
        // Caps Lock: Phosphor's arrow-fat-line-up (⇪), a thin line like every
        // icon here. shell/data/icons.json has no name for it, so the glyph
        // is drawn straight from the icon font.
        Item {
            id: caps
            readonly property bool on: field.lock.capsLock
            anchors.verticalCenter: parent.verticalCenter
            width: on ? Tokens.iconSize : 0
            height: Tokens.iconSize
            clip: true
            Behavior on width { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
            Text {
                anchors.centerIn: parent
                text: ""
                font.family: Tokens.fontIcons
                font.pixelSize: Tokens.iconSize
                color: Colors.text
                opacity: caps.on ? 0.9 : 0
                Behavior on opacity { enabled: Motion.enabled; EaseAnim {} }
            }
        }
    }
}
