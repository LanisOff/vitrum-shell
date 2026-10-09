import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

/*
 * vitrum for SDDM: the lock screen before login — the blurred wallpaper, the
 * time cut out of glass, your picture and a greeting, a glass capsule for the
 * password (dots, the keyboard layout, Caps Lock), the user when there are
 * several, the session, and power actions.
 *
 * It moves like the lock screen: the wallpaper settles and blurs in while the
 * blocks rise one after another; typing pops dots in; a light sweeps the field
 * while SDDM checks; a wrong password blushes the glass and the dots red and
 * swings the capsule once, then the dots go out together; switching users
 * cross-fades the picture and the name. A good password lets everything go
 * and the wallpaper sharpens: the desktop starts on the same picture.
 *
 * Glass.qml (with glass.frag.qsb) is the shell's own glass, copied here.
 * The picture, palette and day/night times come from the picked user's
 * /var/lib/vitrum/login/<user>/ (the shell keeps it through vitrum's root
 * helper), else from theme.conf, which the installer writes.
 */
Rectangle {
    id: root
    width: 1920; height: 1080
    color: cBg

    // The picked user's palette (dark scheme) when the shell left one, else theme.conf.
    property var pal: ({})
    property var info: ({})
    readonly property color cText: pal.text || config.text || "#eceef2"
    readonly property color cDim: pal.textDim || config.textDim || "#a3a8b3"
    readonly property color cAccent: pal.accent || config.accent || "#8ab4f8"
    readonly property color cOnAccent: pal.onAccent || config.onAccent || "#0b1a33"
    readonly property color cSurface: pal.surface || config.surface || "#1f2125"
    readonly property color cDanger: pal.danger || config.danger || "#ef6b6b"
    readonly property color cBg: pal.bg || config.bg || "#141518"
    readonly property string fontName: info.font || config.font || "Inter"
    readonly property real unit: Math.max(1, height / 1080)

    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    // The remembered session; on a first login (no last user) niri with vitrum, if it is installed.
    property int sessionIndex: {
        // The remembered one only while it still exists (vitrum.desktop became niri.desktop).
        if (userModel.lastUser && sessionModel.lastIndex >= 0) return sessionModel.lastIndex;
        for (let i = 0; i < sessionModel.rowCount(); i++)
            if (String(sessionModel.data(sessionModel.index(i, 0), Qt.UserRole + 2)).indexOf("/usr/local/share/wayland-sessions/niri.desktop") >= 0) return i;
        return Math.max(0, sessionModel.lastIndex);
    }
    // No users listed (LDAP, SSSD, or outside SDDM's UID range): a name field instead.
    readonly property bool typeName: userModel.count === 0
    property string error: ""
    property bool busy: false
    property bool leaving: false

    function userName(i) { return typeName ? nameField.text.trim() : (userModel.data(userModel.index(i, 0), Qt.UserRole + 1) || ""); }
    function realName(i) { return userModel.data(userModel.index(i, 0), Qt.UserRole + 2) || userName(i); }
    function userIcon(i) { return typeName ? "" : (userModel.data(userModel.index(i, 0), Qt.UserRole + 4) || ""); }
    function needsPassword(i) { return typeName || userModel.data(userModel.index(i, 0), Qt.UserRole + 5) !== false; }
    function sessionName(i) { return sessionModel.data(sessionModel.index(i, 0), Qt.UserRole + 4) || ""; }

    // What the greeting calls you: the first word of the real name, else the login.
    function firstName(i) {
        const real = String(realName(i) || "").split(",")[0].trim().split(/\s+/)[0] || "";
        const u = real || String(userName(i) || "");
        return u ? u.charAt(0).toUpperCase() + u.slice(1) : "";
    }
    function greeting(hour, name) {
        const part = hour >= 5 && hour < 12 ? "morning" : hour >= 12 && hour < 17 ? "afternoon" : hour >= 17 && hour < 22 ? "evening" : "night";
        return "Good " + part + (name ? ", " + name : "");
    }

    function login() {
        if (busy || leaving || !userName(userIndex) || (!password.text && needsPassword(userIndex))) return;
        busy = true; error = "";
        sddm.login(userName(userIndex), password.text, sessionIndex);
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false;
            root.error = "Wrong password";
            capsule.refuse();
            password.text = "";
            password.forceActiveFocus();
        }
        function onLoginSucceeded() { root.busy = false; root.leaving = true; }
    }

    // ------------------------------------------------ the user's login folder ---
    // What the shell left, checked and copied by vitrum's root helper (never
    // read from the user's home). Files are read with XMLHttpRequest
    // (QML_XHR_ALLOW_FILE_READ, set by the installer).
    readonly property string loginDir: !typeName && userName(userIndex) ? "/var/lib/vitrum/login/" + userName(userIndex) : ""
    function readJson(path, done) {
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            let v = null;
            try { v = JSON.parse(x.responseText); } catch (e) { v = null; }
            done(v);
        };
        try { x.open("GET", "file://" + path); x.send(); } catch (e) { done(null); }
    }
    function loadUser() {
        if (!loginDir) { pal = {}; info = {}; return; }
        const dir = loginDir;
        readJson(dir + "/login.json", v => { if (dir === root.loginDir) root.info = v || {}; });
        readJson(dir + "/palette.json", v => {
            if (dir !== root.loginDir) return;
            const d = v && v.palette && v.palette.dark;
            root.pal = d && typeof d === "object" ? d : {};
        });
    }
    onLoginDirChanged: loadUser()

    // Day or night by the user's sunrise and sunset (or schedule).
    function minutes(hhmm) { const p = String(hhmm || "").split(":"); return (parseInt(p[0], 10) || 0) * 60 + (parseInt(p[1], 10) || 0); }
    readonly property bool isDay: {
        const m = now.getHours() * 60 + now.getMinutes();
        const l = minutes(info.light || "07:00"), d = minutes(info.dark || "19:30");
        return l < d ? (m >= l && m < d) : (m >= l || m < d);
    }
    readonly property string userWallpaper: loginDir ? "file://" + loginDir + "/" + (isDay ? "day" : "night") : ""

    // ------------------------------------------------------- choreography ---
    property real enter: 0
    NumberAnimation on enter { from: 0; to: 1; duration: 1100; easing.type: Easing.Linear }
    property real leave: leaving ? 1 : 0
    Behavior on leave { NumberAnimation { duration: 650; easing.type: Easing.InOutCubic } }
    function rise(order) {
        const t = Math.max(0, Math.min(1, (enter - order * 0.075) / 0.55));
        return 1 - Math.pow(1 - t, 3);
    }

    // ------------------------------------------------------- background ---
    // The user's own picture when there is one, else the installer's.
    Image { id: userWall; source: root.userWallpaper; asynchronous: true; visible: false }
    readonly property string wallSource: userWall.status === Image.Ready ? root.userWallpaper : (config.background || "")
    readonly property real wallScale: 1 + (0.1 - 0.06 * Math.min(1, root.enter * 1.3)) * (1 - root.leave)

    // What the glass looks through: the wallpaper, blurred, and the dim on it.
    Item {
        id: wallBackdrop
        anchors.fill: parent
        Image {
            id: wall
            anchors.fill: parent
            source: root.wallSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: wall
            visible: wall.status === Image.Ready
            blurEnabled: true
            blurMax: 64
            // Blurs in, and sharpens again on the way to the session.
            blur: Math.min(1, root.enter * 1.4) * 0.85 * (1 - root.leave)
            // Larger than the screen while blurred: the blurred edges would pull in transparency.
            scale: root.wallScale
            opacity: Math.min(1, root.enter * 3)
        }
        Rectangle {
            anchors.fill: parent
            visible: wall.status !== Image.Ready
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.darker(root.cAccent, 3.2) }
                GradientStop { position: 1; color: root.cBg }
            }
        }
        Rectangle { anchors.fill: parent; color: root.cBg; opacity: Number(config.dim || 0.32) * Math.min(1, root.enter * 2) * (1 - root.leave) }
    }
    ShaderEffectSource { id: backdropTex; sourceItem: wallBackdrop; visible: false; hideSource: false }
    // The clock is clear glass: sharp through the digits, blurred around them.
    Item {
        id: clearBackdrop
        anchors.fill: parent
        visible: false
        Image {
            anchors.fill: parent
            source: root.wallSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            scale: root.wallScale
        }
        Rectangle { anchors.fill: parent; color: root.cBg; opacity: 0.12 }
    }
    ShaderEffectSource { id: clearTex; sourceItem: clearBackdrop; visible: false; hideSource: false }

    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }

    // ----------------------------------------------------------- centre ---
    Column {
        id: centre
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -root.height * 0.04
        spacing: 16 * root.unit
        transform: Translate { y: -root.leave * 40 * root.unit }

        // The time cut out of glass, as on the lock screen; the date under it.
        Rise {
            order: 0
            anchors.horizontalCenter: parent.horizontalCenter
            width: clockCol.width; height: clockCol.height
            Column {
                id: clockCol
                spacing: 2 * root.unit
                Glass {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: clock.width; height: clock.height
                    backdrop: clearBackdrop
                    source: clearTex
                    bevel: clock.size * 0.08
                    refraction: clock.size * 0.22
                    edgeLight: 0.8
                    fringing: 0.35
                    saturation: 1.25
                    brightness: 0.06
                    tint: Qt.rgba(1, 1, 1, 0.05)
                    shadow: 0.4
                    RollClock {
                        id: clock
                        time: Qt.formatTime(root.now, root.info.h24 === false ? "h:mm" : "HH:mm")
                        size: Math.round(root.height * 0.17)
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(root.now, "dddd, d MMMM")
                    color: root.cText
                    font { family: root.fontName; pixelSize: 20 * root.unit; weight: Font.DemiBold }
                }
            }
        }
        Item { width: 1; height: 12 * root.unit }

        // You: the picture (SDDM's face icon) or your initial, and a greeting.
        // Switching users fades the old one out and the new one in.
        Item {
            id: who
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300 * root.unit
            height: avatarRise.height + 14 * root.unit + helloRise.height
            visible: !root.typeName
            property int shown: root.userIndex
            property real swap: 1
            SequentialAnimation {
                id: swapAnim
                NumberAnimation { target: who; property: "swap"; to: 0; duration: 140; easing.type: Easing.InCubic }
                ScriptAction { script: who.shown = root.userIndex }
                NumberAnimation { target: who; property: "swap"; to: 1; duration: 220; easing.type: Easing.OutCubic }
            }
            Connections { target: root; function onUserIndexChanged() { swapAnim.restart(); } }

            Rise {
                id: avatarRise
                order: 2
                anchors.horizontalCenter: parent.horizontalCenter
                width: 96 * root.unit; height: width
                opacity: root.rise(2) * (1 - root.leave) * who.swap
                scale: 0.9 + 0.1 * who.swap
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: root.cAccent
                    border.width: 2; border.color: Qt.rgba(1, 1, 1, 0.25)
                    Text {
                        anchors.centerIn: parent
                        visible: face.status !== Image.Ready
                        text: (root.firstName(who.shown) || "?").charAt(0)
                        color: root.cOnAccent
                        font { family: root.fontName; pixelSize: 40 * root.unit; weight: Font.DemiBold }
                    }
                    Image {
                        id: face
                        anchors.fill: parent; anchors.margins: 2
                        source: root.userIcon(who.shown)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: face
                        source: face
                        visible: face.status === Image.Ready
                        maskEnabled: true
                        maskSource: faceMask
                    }
                    Item {
                        id: faceMask
                        anchors.fill: face
                        layer.enabled: true
                        visible: false
                        Rectangle { anchors.fill: parent; radius: width / 2 }
                    }
                }
            }
            Rise {
                id: helloRise
                order: 3
                anchors { horizontalCenter: parent.horizontalCenter; top: avatarRise.bottom; topMargin: 14 * root.unit }
                width: hello.implicitWidth; height: hello.implicitHeight
                opacity: root.rise(3) * (1 - root.leave) * who.swap
                Text {
                    id: hello
                    text: root.greeting(root.now.getHours(), root.firstName(who.shown))
                    color: root.cText
                    font { family: root.fontName; pixelSize: 19 * root.unit; weight: Font.DemiBold }
                }
            }
        }

        // Users, when there is a choice.
        Rise {
            order: 3
            anchors.horizontalCenter: parent.horizontalCenter
            visible: userModel.count > 1
            width: users.implicitWidth; height: users.implicitHeight
            Row {
                id: users
                spacing: 10 * root.unit
                Repeater {
                    model: userModel
                    delegate: GlassPane {
                        id: chip
                        required property int index
                        required property string name
                        required property string realName
                        readonly property bool on: index === root.userIndex
                        height: 36 * root.unit; radius: height / 2
                        width: ur.implicitWidth + 24 * root.unit
                        tint: on ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.85) : um.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07)
                        Behavior on tint { ColorAnimation { duration: 180 } }
                        scale: um.pressed ? 0.94 : 1
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Text { id: ur; anchors.centerIn: parent; text: chip.realName || chip.name; color: chip.on ? root.cOnAccent : root.cText; font { family: root.fontName; pixelSize: 14 * root.unit } }
                        MouseArea { id: um; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.userIndex = chip.index; password.forceActiveFocus(); } }
                    }
                }
            }
        }
        Rise {
            order: 3
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.typeName
            width: 300 * root.unit; height: 44 * root.unit
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.78)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
                TextInput {
                    id: nameField
                    anchors { fill: parent; leftMargin: 20 * root.unit; rightMargin: 20 * root.unit }
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.cText
                    font { family: root.fontName; pixelSize: 17 * root.unit }
                    KeyNavigation.tab: password
                    onAccepted: password.forceActiveFocus()
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: !nameField.text; text: "User name"; color: root.cDim; font { family: root.fontName; pixelSize: 17 * root.unit } }
                }
            }
        }

        // The capsule: password (as dots), layout, go.
        Rise {
            order: 4
            anchors.horizontalCenter: parent.horizontalCenter
            width: capsule.width; height: capsule.height
            GlassPane {
                id: capsule
                width: 440 * root.unit; height: 54 * root.unit; radius: height / 2
                tint: Qt.tint(Qt.rgba(1, 1, 1, 0.07), Qt.rgba(root.cDanger.r, root.cDanger.g, root.cDanger.b, 0.38 * flash))
                outline: Qt.tint(Qt.rgba(1, 1, 1, 0.14), Qt.rgba(root.cDanger.r, root.cDanger.g, root.cDanger.b, 0.85 * flash))
                clip: true

                // A refusal: the glass and the dots blush, one damped swing, then
                // the dots go out together and the hint comes back.
                property real flash: 0
                property real swing: 0
                property bool refusing: false
                property real dotsOpacity: 1
                transform: Translate { x: 22 * root.unit * Math.sin(capsule.swing * Math.PI * 6) * Math.pow(1 - capsule.swing, 2) }
                function refuse() { refusing = true; refuseAnim.restart(); }
                SequentialAnimation {
                    id: refuseAnim
                    ParallelAnimation {
                        NumberAnimation { target: capsule; property: "swing"; from: 0; to: 1; duration: 520 }
                        SequentialAnimation {
                            NumberAnimation { target: capsule; property: "flash"; to: 1; duration: 90; easing.type: Easing.OutCubic }
                            PauseAnimation { duration: 260 }
                            NumberAnimation { target: capsule; property: "flash"; to: 0; duration: 520; easing.type: Easing.InOutCubic }
                        }
                        SequentialAnimation {
                            PauseAnimation { duration: 380 }
                            NumberAnimation { target: capsule; property: "dotsOpacity"; to: 0; duration: 160; easing.type: Easing.InCubic }
                        }
                    }
                    ScriptAction { script: { capsule.refusing = false; capsule.dotsOpacity = 1; dots.sync(password.text.length, false); } }
                }

                // The checking sweep.
                Rectangle {
                    id: sweep
                    visible: root.busy
                    width: capsule.width * 0.35; height: capsule.height
                    property real p: 0
                    x: -width + p * (capsule.width + width)
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 0.5; color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.3) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                    NumberAnimation on p { running: sweep.visible; loops: Animation.Infinite; from: 0; to: 1; duration: 1100; easing.type: Easing.InOutQuad }
                }

                TextInput {
                    id: password
                    anchors { left: parent.left; right: layoutChip.left; verticalCenter: parent.verticalCenter; leftMargin: 24 * root.unit; rightMargin: 10 * root.unit }
                    // Typed into, never shown: the dots are the echo.
                    echoMode: TextInput.Password
                    color: "transparent"
                    selectionColor: "transparent"
                    selectedTextColor: "transparent"
                    cursorDelegate: Item {}
                    font { family: root.fontName; pixelSize: 18 * root.unit }
                    focus: true
                    enabled: !root.busy && !root.leaving
                    clip: true
                    onAccepted: root.login()
                    onTextChanged: { if (text) root.error = ""; if (!capsule.refusing) dots.sync(text.length, true); }
                    Keys.onEscapePressed: text = ""
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: !password.text && dotModel.count === 0 && !capsule.refusing ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                        text: root.busy ? "Signing in…" : "Password"
                        color: root.cDim
                        font { family: root.fontName; pixelSize: 18 * root.unit }
                    }
                    ListView {
                        id: dots
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: 12 * root.unit
                        orientation: ListView.Horizontal
                        interactive: false
                        spacing: 7 * root.unit
                        clip: true
                        opacity: capsule.dotsOpacity
                        model: ListModel { id: dotModel }
                        property bool animated: true
                        function sync(n, anim) {
                            animated = anim;
                            if (!anim && n === 0) dotModel.clear();
                            while (dotModel.count < n) dotModel.append({});
                            while (dotModel.count > n) dotModel.remove(dotModel.count - 1);
                            animated = true;
                            positionViewAtEnd();
                        }
                        delegate: Rectangle { width: 10 * root.unit; height: width; radius: width / 2; color: Qt.tint(root.cText, Qt.rgba(root.cDanger.r, root.cDanger.g, root.cDanger.b, capsule.flash)); y: (dots.height - height) / 2 }
                        add: Transition {
                            enabled: dots.animated
                            NumberAnimation { property: "scale"; from: 0; to: 1; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 }
                        }
                        remove: Transition {
                            enabled: dots.animated
                            NumberAnimation { property: "scale"; to: 0; duration: 140; easing.type: Easing.InCubic }
                            NumberAnimation { property: "opacity"; to: 0; duration: 140 }
                        }
                    }
                }
                Rectangle {
                    id: layoutChip
                    anchors { right: go.left; rightMargin: 8 * root.unit; verticalCenter: parent.verticalCenter }
                    visible: keyboard.layouts.length > 1
                    width: visible ? lt.implicitWidth + 16 * root.unit : 0; height: 28 * root.unit; radius: height / 2
                    color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.25)
                    Text {
                        id: lt
                        anchors.centerIn: parent
                        text: keyboard.layouts.length ? String(keyboard.layouts[keyboard.currentLayout].shortName).toUpperCase() : ""
                        color: root.cText
                        font { family: root.fontName; pixelSize: 12 * root.unit; weight: Font.DemiBold }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length }
                }
                Rectangle {
                    id: go
                    anchors { right: parent.right; rightMargin: 7 * root.unit; verticalCenter: parent.verticalCenter }
                    width: 40 * root.unit; height: width; radius: width / 2
                    color: password.text ? root.cAccent : Qt.rgba(1, 1, 1, 0.08)
                    Behavior on color { ColorAnimation { duration: 180 } }
                    scale: gm.pressed ? 0.88 : password.text ? 1 : 0.94
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                    // An arrow, drawn (the greeter has no icon font of its own).
                    Shape {
                        anchors.centerIn: parent
                        width: 16 * root.unit; height: 14 * root.unit
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: password.text ? root.cOnAccent : root.cDim
                            strokeWidth: 2.2 * root.unit
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            startX: 1 * root.unit; startY: 7 * root.unit
                            PathLine { x: 15 * root.unit; y: 7 * root.unit }
                            PathMove { x: 9 * root.unit; y: 1 * root.unit }
                            PathLine { x: 15 * root.unit; y: 7 * root.unit }
                            PathLine { x: 9 * root.unit; y: 13 * root.unit }
                        }
                    }
                    MouseArea { id: gm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.login() }
                }
            }
        }
        Rise {
            order: 5
            anchors.horizontalCenter: parent.horizontalCenter
            width: note.implicitWidth; height: note.implicitHeight
            Text {
                id: note
                text: [root.error, keyboard.capsLock ? "Caps Lock is on" : ""].filter(t => t).join("   ·   ") || " "
                color: root.error ? root.cDanger : root.cDim
                font { family: root.fontName; pixelSize: 14 * root.unit }
            }
        }
    }

    // ----------------------------------------------- session and power ---
    // Restart and power off ask for a second press within three seconds.
    property string armed: ""
    Timer { id: disarm; interval: 3000; onTriggered: root.armed = "" }
    function power(action) {
        if (action === "suspend") { sddm.suspend(); return; }
        if (armed === action) { armed = ""; if (action === "reboot") sddm.reboot(); else sddm.powerOff(); return; }
        armed = action; disarm.restart();
    }
    Row {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 40 * root.unit }
        spacing: 10 * root.unit
        opacity: root.rise(6) * (1 - root.leave)
        transform: Translate { y: (1 - root.rise(6)) * 30 * root.unit }
        Pill {
            text: "Session: " + root.sessionName(root.sessionIndex)
            onClicked: root.sessionIndex = (root.sessionIndex + 1) % Math.max(1, sessionModel.rowCount())
        }
        Pill { visible: sddm.canSuspend; text: "Suspend"; onClicked: root.power("suspend") }
        Pill { visible: sddm.canReboot; text: root.armed === "reboot" ? "Press again to restart" : "Restart"; danger: root.armed === "reboot"; onClicked: root.power("reboot") }
        Pill { visible: sddm.canPowerOff; text: root.armed === "poweroff" ? "Press again to power off" : "Power off"; danger: root.armed === "poweroff"; onClicked: root.power("poweroff") }
    }
    Text {
        anchors { right: parent.right; top: parent.top; margins: 28 * root.unit }
        text: sddm.hostName
        color: root.cDim
        opacity: root.rise(6) * (1 - root.leave)
        font { family: root.fontName; pixelSize: 14 * root.unit }
    }

    // After a good password everything lets go and the wallpaper sharpens: the
    // last frame is the plain picture the desktop starts on.

    /// A block that rises in with the entrance and fades out on the way to the session.
    component Rise: Item {
        property int order: 0
        opacity: root.rise(order) * (1 - root.leave)
        transform: Translate { y: (1 - root.rise(order)) * 30 * root.unit }
    }

    component Pill: GlassPane {
        id: p
        property string text: ""
        property bool danger: false
        signal clicked()
        height: 36 * root.unit; radius: height / 2
        width: pt.implicitWidth + 28 * root.unit
        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
        tint: danger ? Qt.rgba(root.cDanger.r, root.cDanger.g, root.cDanger.b, 0.8) : pm.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07)
        Behavior on tint { ColorAnimation { duration: 180 } }
        scale: pm.pressed ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Text { id: pt; anchors.centerIn: parent; text: p.text; color: p.danger ? "white" : root.cText; font { family: root.fontName; pixelSize: 14 * root.unit } }
        MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: p.clicked() }
    }

    /// A pane of glass over the blurred wallpaper; children sit on top.
    component GlassPane: Item {
        id: pane
        property real radius: 20
        property color tint: Qt.rgba(1, 1, 1, 0.07)
        property color outline: Qt.rgba(1, 1, 1, 0.14)
        Glass {
            anchors.fill: parent
            backdrop: wallBackdrop
            source: backdropTex
            bevel: Math.min(18, pane.height * 0.35)
            refraction: Math.min(26, pane.height * 0.45)
            edgeLight: 0.5
            tint: pane.tint
            Rectangle { anchors.fill: parent; radius: pane.radius }
        }
        Rectangle { anchors.fill: parent; radius: pane.radius; color: "transparent"; border.width: 1; border.color: pane.outline }
    }

    /// The clock's digits; each rolls up when it changes.
    component RollClock: Row {
        id: rc
        property string time: ""
        property real size: 160
        Repeater {
            model: rc.time.length
            delegate: Item {
                id: cell
                required property int index
                readonly property string ch: rc.time.charAt(index)
                property string shown: ch
                property string old: ""
                property real t: 1
                width: Math.max(nowT.implicitWidth, goneT.implicitWidth)
                height: nowT.implicitHeight
                clip: true
                onChChanged: { old = shown; shown = ch; roll.restart(); }
                NumberAnimation { id: roll; target: cell; property: "t"; from: 0; to: 1; duration: 530; easing.type: Easing.OutCubic }
                Text {
                    id: goneT
                    text: cell.old; color: "white"
                    opacity: 1 - cell.t; y: -cell.t * cell.height * 0.6; visible: cell.t < 1
                    font { family: root.fontName; pixelSize: rc.size; weight: Font.Bold; features: { "tnum": 1 } }
                }
                Text {
                    id: nowT
                    text: cell.shown; color: "white"
                    opacity: cell.t; y: (1 - cell.t) * cell.height * 0.6
                    font { family: root.fontName; pixelSize: rc.size; weight: Font.Bold; features: { "tnum": 1 } }
                }
            }
        }
    }

    Component.onCompleted: { loadUser(); (typeName ? nameField : password).forceActiveFocus(); }
}
