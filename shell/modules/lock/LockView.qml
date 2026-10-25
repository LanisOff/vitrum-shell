import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import "root:/lib/lock.js" as Lib

/*
 * What one output shows while locked. Three animated quantities drive it:
 *   enter   0 → 1 as the lock appears: the wallpaper settles and blurs, the
 *           blocks rise and fade in one after another (each has an `order`:
 *           the time, the date, you, the greeting, the field, …), short,
 *           eased out with no overshoot;
 *   leave   0 → 1 after a good password: the blocks float off, the wallpaper
 *           sharpens and a soft dichroic flash (accent → accent2) blooms out
 *           of the field and fades, so the desktop appears without a cut;
 *   amb     quiet (ambient, after lock.ambientSeconds without input): the
 *           field, the power buttons, the status row and the rest recede to
 *           Lib.QUIET_OPACITY; the clock and the player stay as they are. Any
 *           key or pointer motion brings the rest back.
 * With Motion.enabled false all three jump.
 */
Item {
    id: view
    required property var lock
    property string outputName: ""

    property real enter: 0
    Component.onCompleted: { enterAnim.start(); faceCheck.running = true; view.lock.checkCaps(); }
    NumberAnimation { id: enterAnim; target: view; property: "enter"; from: 0; to: 1; duration: Motion.enabled ? Motion.emphasized * 2.2 : 0; easing.type: Easing.Linear }

    property real leave: lock.leaving ? 1 : 0
    Behavior on leave { enabled: Motion.enabled; NumberAnimation { duration: view.lock.leaveDuration; easing.type: Easing.InOutCubic } }

    property real amb: lock.ambient ? 1 : 0
    Behavior on amb { enabled: Motion.enabled; NumberAnimation { duration: Motion.emphasized * 2; easing.type: Easing.InOutCubic } }

    /// The highest `order` of the entrance (the power buttons).
    readonly property int lastOrder: 8
    /// 0 → 1 for the block with this order, staggered along `enter`, eased out.
    function rise(order) { return Lib.rise(view.enter, order, view.lastOrder); }
    /// How much of a block that is not the clock or the player shows.
    readonly property real chrome: Lib.chrome(amb, leave)

    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: view.now = new Date() }

    // Any pointer motion wakes the screen from ambient.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: view.lock.poke()
    }

    // ----------------------------------------------------------- wallpaper --
    readonly property string wallSource: Lib.lockBackground(
        Wallpaper.pathFor(outputName),
        (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/vitrum/poster.png")
    // What the glass looks through: the wallpaper, blurred, and the dim on it.
    Item {
        id: backdrop
        anchors.fill: parent
        Image {
            id: wall
            anchors.fill: parent
            source: view.wallSource ? "file://" + view.wallSource : ""
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
            // Blurs in as the lock appears, sharpens again on the way out.
            blur: Math.min(1, view.enter * 1.4) * (1 - view.leave) * 0.85
            // Settles from 1.1 to 1.04: blurred edges pull in transparency, so the
            // picture stays a little larger than the screen.
            scale: 1.1 - 0.06 * Math.min(1, view.enter * 1.3)
            opacity: Math.min(1, view.enter * 3)
        }
        Rectangle {
            anchors.fill: parent
            color: Colors.bg
            opacity: (Materials.of("lock") === "solid" ? 0.92 : 0.32) * Math.min(1, view.enter * 2) * (1 - view.leave) + 0.3 * view.amb
        }
    }
    // One texture of it for every piece of glass.
    ShaderEffectSource { id: backdropTex; sourceItem: backdrop; visible: false; hideSource: false }
    readonly property Item glassBackdrop: backdrop
    readonly property Item glassSource: backdropTex
    // The clock is clear glass: through it the picture is sharp, bent at the
    // rims, while everything around is blurred.
    Item {
        id: clearBackdrop
        anchors.fill: parent
        visible: false
        Image {
            anchors.fill: parent
            source: wall.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            scale: 1.1 - 0.06 * Math.min(1, view.enter * 1.3)
        }
        Rectangle { anchors.fill: parent; color: Colors.bg; opacity: 0.12 }
    }
    ShaderEffectSource { id: clearTex; sourceItem: clearBackdrop; visible: false; hideSource: false }

    // -------------------------------------------------------------- centre --
    Column {
        id: centre
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -parent.height * 0.04 - view.lift
        spacing: Tokens.gap * 2
        // Floats up a little as the screen unlocks.
        transform: Translate { y: -view.leave * Tokens.islandHeight }

        // The time, cut out of glass: the wallpaper bends through the digits.
        // It and the date stay as they are in the quiet screen.
        Rise {
            order: 0
            keep: true
            anchors.horizontalCenter: parent.horizontalCenter
            width: clockBox.width; height: clockBox.height
            Item {
                id: clockBox
                width: clockGlass.visible ? clockGlass.width : paintedClock.width
                height: clockGlass.visible ? clockGlass.height : paintedClock.height
                Glass {
                    id: clockGlass
                    width: clock.width; height: clock.height
                    visible: Materials.of("lock") !== "solid"
                    backdrop: clearBackdrop
                    source: clearTex
                    bevel: clock.size * 0.08
                    refraction: clock.size * 0.22
                    edgeLight: 0.8
                    fringing: 0.35
                    saturation: 1.25
                    brightness: 0.06
                    tint: Qt.rgba(1, 1, 1, Colors.dark ? 0.05 : 0.12)
                    shadow: 0.4
                    LockClock {
                        id: clock
                        time: Qt.formatTime(view.now, Settings.get("clock.h24", true) ? "HH:mm" : "h:mm")
                        size: Math.round(view.height * 0.17)
                        weight: Font.Bold
                        color: "white"
                    }
                }
                // Solid lock: the same clock, painted.
                LockClock {
                    id: paintedClock
                    visible: !clockGlass.visible
                    time: clock.time; size: clock.size; weight: clock.weight
                }
            }
        }
        // The date and the weather, just under the time.
        Rise {
            order: 1
            keep: true
            anchors.horizontalCenter: parent.horizontalCenter
            width: dateRow.width; height: dateRow.height
            // Pulled up to the digits: the Column's spacing is for the blocks.
            shiftY: -Tokens.gap * 1.8
            Row {
                id: dateRow
                spacing: Tokens.gap
                Label { text: Qt.formatDate(view.now, "dddd, d MMMM"); size: Tokens.textLarge * 1.15; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                Label { visible: weatherNow.visible; text: "·"; size: Tokens.textLarge * 1.15; role: "dim"; anchors.verticalCenter: parent.verticalCenter }
                Row {
                    id: weatherNow
                    visible: Weather.enabled && Weather.ready
                    spacing: Tokens.gap * 0.5
                    anchors.verticalCenter: parent.verticalCenter
                    Icon { name: Weather.ready ? Weather.symbol(Weather.current.code, Weather.current.isDay) : "weather-cloudy"; anchors.verticalCenter: parent.verticalCenter }
                    Label { text: Weather.ready ? Math.round(Weather.current.temp) + Weather.unit : ""; size: Tokens.textLarge * 1.15; font.weight: Font.DemiBold; numeric: true; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
        // (The date sits pulled up: this gap and the spacing make up the room under it.)
        Item { width: 1; height: 1 }

        // You: your picture (~/.face, ~/.face.icon or AccountsService's), or
        // your initial on round tinted glass, inside a glass rim and a thin
        // dichroic ring (accent → accent2); the greeting just under it.
        Rise {
            order: 2
            anchors.horizontalCenter: parent.horizontalCenter
            width: Tokens.islandHeight * 3; height: width
            Item {
                id: avatar
                anchors.fill: parent
                readonly property real ring: Math.max(2, Tokens.islandHeight * 0.08)
                readonly property real gap: Math.max(2, Tokens.islandHeight * 0.1)
                readonly property bool hasPicture: face.status === Image.Ready

                // The ring: an annulus filled with the diagonal accent → accent2.
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "transparent"
                        strokeWidth: 0
                        fillRule: ShapePath.OddEvenFill
                        fillGradient: LinearGradient {
                            x1: 0; y1: 0; x2: avatar.width; y2: avatar.height
                            GradientStop { position: 0; color: Colors.accent }
                            GradientStop { position: 1; color: Colors.accent2 }
                        }
                        PathAngleArc { centerX: avatar.width / 2; centerY: avatar.height / 2; radiusX: avatar.width / 2; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
                        PathAngleArc { centerX: avatar.width / 2; centerY: avatar.height / 2; radiusX: avatar.width / 2 - avatar.ring; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
                    }
                }
                // The disc of glass inside it, with its own rim.
                Rectangle {
                    id: disc
                    anchors.fill: parent
                    anchors.margins: avatar.ring + avatar.gap
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, Colors.dark ? 0.07 : 0.16)
                    ShellTint {
                        anchors.fill: parent
                        radius: width / 2
                        group: "lock"
                        active: !avatar.hasPicture
                        rim: false
                    }
                    Label {
                        anchors.centerIn: parent
                        visible: !avatar.hasPicture
                        text: Lib.initial(view.name)
                        size: Tokens.textTitle * 1.4
                        font.weight: Font.DemiBold
                    }
                    Image {
                        id: face
                        anchors.fill: parent
                        // Looked up again on every lock: the picture may be new since the last.
                        source: view.facePath ? "file://" + view.facePath + "?" + view.lock.lockedAt : ""
                        cache: false
                        asynchronous: true
                        sourceSize.width: width * 2; sourceSize.height: height * 2
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: face
                        source: face
                        visible: avatar.hasPicture
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
                    // The glass rim, over the picture too.
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: Tokens.hairline
                        border.color: Qt.rgba(1, 1, 1, Colors.dark ? 0.32 : 0.6)
                    }
                }
            }
        }
        Rise {
            order: 3
            anchors.horizontalCenter: parent.horizontalCenter
            width: hello.width; height: hello.height
            // Close under the picture: one group with it, apart from the field.
            shiftY: -Tokens.gap * 0.9
            Label { id: hello; text: Lib.greeting(view.now.getHours(), view.name); size: Tokens.textLarge; font.weight: Font.Medium; font.letterSpacing: 0.2 }
        }

        Rise {
            order: 4
            anchors.horizontalCenter: parent.horizontalCenter
            width: field.width; height: field.height
            LockField { id: field; lock: view.lock; backdrop: view.glassBackdrop; source: view.glassSource }
        }
        Rise {
            order: 4
            anchors.horizontalCenter: parent.horizontalCenter
            width: status.width; height: status.height
            Label {
                id: status
                text: view.lock.error || (view.lock.busy ? "Checking…" : " ")
                role: view.lock.error ? "danger" : "dim"
                Behavior on opacity { enabled: Motion.enabled; EaseAnim {} }
            }
        }
    }

    // What came in while locked: under the centre, never into the player (or
    // the status row) — as many as fit there, the rest clipped.
    readonly property real notesBottom: (player.visible ? player.y : statusRow.y) - Tokens.gap * 2
    // Notifications that would not fit lift the centre (down to a margin at
    // the top) — from where it sits unlifted, so the lift never feeds itself.
    // Not animated: a Behavior here never left 0 under the nested test session.
    property real lift: {
        const baseY = (height - centre.height) / 2 - height * 0.04;
        const room = notesBottom - (baseY + centre.height + centre.spacing);
        return Math.max(0, Math.min(notes.wanted - room, baseY - height * 0.05));
    }
    Rise {
        order: 5
        anchors.horizontalCenter: parent.horizontalCenter
        y: centre.y + centre.height + centre.spacing
        width: notes.width
        height: Math.max(0, Math.min(notes.height, view.notesBottom - y))
        clip: true
        LockNotifications {
            id: notes
            since: view.lock.lockedAt; backdrop: view.glassBackdrop; source: view.glassSource
            maxHeight: Math.max(0, view.notesBottom - parent.y)
        }
    }

    // The player keeps showing in ambient: it is what you look at from afar.
    LockPlayer {
        id: player
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: statusRow.top
        anchors.bottomMargin: Tokens.gap * 2
        appear: view.rise(6) * (1 - view.leave)
    }

    // ------------------------------------------------- status and power --
    // Small matching glass islands: the network, the battery (if any) and the
    // keyboard layout (a click switches it: typing the password in the wrong
    // layout is the classic lock-screen trap).
    Row {
        id: statusRow
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Tokens.islandHeight * 1.5 }
        spacing: Tokens.gap * 0.75
        opacity: view.rise(7) * view.chrome
        transform: Translate { y: (1 - view.rise(7)) * Tokens.islandHeight }
        StatusIsland {
            icon: Lib.networkIcon(Network.kind, Network.strength, Network.online)
            text: Lib.networkLabel(Network.kind, Network.name, Network.online)
            dim: !Network.online
        }
        StatusIsland {
            visible: Power.hasBattery
            icon: Power.charging ? "bolt" : "battery"
            text: Math.round(Power.percentage) + "%"
            numeric: true
        }
        StatusIsland {
            visible: Niri.keyboardShort.length > 0
            icon: "keyboard"
            text: Niri.keyboardShort
            clickable: Niri.keyboardLayouts.length > 1
            onClicked: Niri.switchLayout(true)
        }
    }
    LockPower {
        backdrop: view.glassBackdrop; source: view.glassSource
        anchors { right: parent.right; bottom: parent.bottom; margins: Tokens.islandHeight * 1.5 }
        visible: Settings.get("lock.power", true)
        opacity: view.rise(8) * view.chrome
    }

    // ------------------------------------------------- the way out --
    // A good password: a soft dichroic light (accent → accent2) blooms out of
    // the field as the blocks float off, and fades with them. Drawn only while
    // leaving; with Motion.enabled false `leave` jumps and it never shows.
    property point flashAt: Qt.point(width / 2, height / 2)
    Connections {
        target: view.lock
        function onLeavingChanged() {
            if (view.lock.leaving) view.flashAt = field.mapToItem(view, field.width / 2, field.height / 2);
        }
    }
    Shape {
        id: bloom
        anchors.fill: parent
        readonly property real k: Math.sin(Math.PI * Math.max(0, Math.min(1, view.leave)))
        visible: k > 0.001
        opacity: k * 0.6
        ShapePath {
            strokeColor: "transparent"
            strokeWidth: 0
            fillGradient: RadialGradient {
                centerX: view.flashAt.x; centerY: view.flashAt.y
                focalX: centerX; focalY: centerY
                centerRadius: Math.max(view.width, view.height) * (0.2 + 0.7 * view.leave)
                focalRadius: 0
                GradientStop { position: 0; color: Colors.alpha(Colors.accent, 0.55) }
                GradientStop { position: 0.4; color: Colors.alpha(Colors.accent2, 0.32) }
                GradientStop { position: 1; color: "transparent" }
            }
            startX: 0; startY: 0
            PathLine { x: view.width; y: 0 }
            PathLine { x: view.width; y: view.height }
            PathLine { x: 0; y: view.height }
            PathLine { x: 0; y: 0 }
        }
    }

    // ----------------------------------------------------------- helpers --
    // The picture: the first of ~/.face, ~/.face.icon and AccountsService's
    // icon that can be read, asked on every lock (it may be new since the last).
    property string facePath: ""
    Process {
        id: faceCheck
        command: ["sh", "-c", 'for f in "$@"; do if [ -r "$f" ] && [ -s "$f" ]; then printf %s "$f"; exit 0; fi; done; exit 1', "sh"]
            .concat(Lib.faceCandidates(Quickshell.env("HOME"), SysInfo.userName || Quickshell.env("USER")))
        stdout: StdioCollector { onStreamFinished: view.facePath = text.trim() }
    }
    Connections { target: view.lock; function onLockedAtChanged() { faceCheck.running = true; } }
    readonly property string name: Lib.firstName(SysInfo.userRealName, SysInfo.userName || Quickshell.env("USER"))

    /// A block that rises in with the entrance; `keep` stays as it is in the quiet screen.
    component Rise: Item {
        property int order: 0
        property bool keep: false
        property real shiftY: 0
        opacity: view.rise(order) * (keep ? 1 - view.leave : view.chrome)
        transform: Translate { y: (1 - view.rise(order)) * Tokens.islandHeight * 0.9 + shiftY }
    }

    /// One island of the status row: a line icon and a few words on glass,
    /// all the same height and corners; `clickable` lifts under the pointer.
    component StatusIsland: LockGlass {
        id: island
        property string icon: ""
        property string text: ""
        property bool numeric: false
        property bool dim: false
        property bool clickable: false
        signal clicked()
        backdrop: view.glassBackdrop
        source: view.glassSource
        height: Tokens.islandHeight
        radius: Tokens.radiusIsland
        width: islandRow.implicitWidth + 2 * Tokens.padding
        tint: island.clickable && islandMouse.containsMouse ? Colors.alpha(Colors.text, islandMouse.pressed ? 0.18 : 0.13) : Qt.rgba(1, 1, 1, Colors.dark ? 0.07 : 0.16)
        Behavior on tint { enabled: Motion.enabled; ColorAnim {} }
        Row {
            id: islandRow
            anchors.centerIn: parent
            spacing: Tokens.gap * 0.7
            Icon { name: island.icon; size: Tokens.iconSize; color: island.dim ? Colors.textDim : Colors.text; anchors.verticalCenter: parent.verticalCenter }
            Label { text: island.text; numeric: island.numeric; role: island.dim ? "dim" : "text"; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea {
            id: islandMouse
            anchors.fill: parent
            enabled: island.clickable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: island.clicked()
        }
    }
}
