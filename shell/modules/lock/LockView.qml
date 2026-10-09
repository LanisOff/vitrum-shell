import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import "root:/lib/lock.js" as Lib

/*
 * What one output shows while locked. Three animated quantities drive it:
 *   enter   0 → 1 as the lock appears: the wallpaper settles and blurs, the
 *           blocks rise in one after another (each has an `order`);
 *   leave   0 → 1 after a good password: the blocks float off and the
 *           wallpaper sharpens, so the desktop appears without a cut;
 *   amb     ambient: everything but the clock and the player fades, the clock
 *           drifts to the middle.
 */
Item {
    id: view
    required property var lock
    property string outputName: ""

    property real enter: 0
    Component.onCompleted: { enterAnim.start(); faceCheck.running = true; }
    NumberAnimation { id: enterAnim; target: view; property: "enter"; from: 0; to: 1; duration: Motion.enabled ? Motion.emphasized * 2.6 : 0; easing.type: Easing.Linear }

    property real leave: lock.leaving ? 1 : 0
    Behavior on leave { enabled: Motion.enabled; NumberAnimation { duration: Motion.emphasized; easing.type: Easing.InOutCubic } }

    property real amb: lock.ambient ? 1 : 0
    Behavior on amb { enabled: Motion.enabled; NumberAnimation { duration: Motion.emphasized * 2; easing.type: Easing.InOutCubic } }

    /// 0 → 1 for the block with this order, staggered along `enter`, eased out.
    function rise(order) {
        const t = Math.max(0, Math.min(1, (view.enter - order * 0.075) / 0.55));
        return 1 - Math.pow(1 - t, 3);
    }
    /// How much of a non-clock block is shown.
    readonly property real chrome: (1 - amb) * (1 - leave)

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
        anchors.verticalCenterOffset: -parent.height * 0.04
        spacing: Tokens.gap * 2
        // Floats up a little as the screen unlocks.
        transform: Translate { y: -view.leave * Tokens.islandHeight }

        // The time, cut out of glass: the wallpaper bends through the digits.
        // The date and the weather under it. In ambient it drifts to the middle.
        Rise {
            order: 0
            keep: true
            anchors.horizontalCenter: parent.horizontalCenter
            width: clockCol.width; height: clockCol.height
            shiftY: view.amb * view.clockToCentre
            Column {
                id: clockCol
                spacing: Tokens.gap * 0.2
                Glass {
                    id: clockGlass
                    anchors.horizontalCenter: parent.horizontalCenter
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
                        size: Math.round(view.height * 0.17 * (1 + 0.08 * view.amb))
                        weight: Font.Bold
                        color: "white"
                    }
                }
                // Solid lock: the same clock, painted.
                LockClock {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !clockGlass.visible
                    height: visible ? implicitHeight : 0
                    time: clock.time; size: clock.size; weight: clock.weight
                }
                Row {
                    id: dateRow
                    anchors.horizontalCenter: parent.horizontalCenter
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
        }
        Item { width: 1; height: Tokens.gap * 1.5 }

        // You: the picture (or your initial) and a greeting.
        Rise {
            order: 2
            anchors.horizontalCenter: parent.horizontalCenter
            width: Tokens.islandHeight * 3; height: width
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Colors.alpha(Colors.accent, 0.85)
                border.width: 2; border.color: Colors.alpha(Colors.text, 0.25)
                Label {
                    anchors.centerIn: parent
                    visible: face.status !== Image.Ready
                    text: Lib.initial(view.name)
                    role: "onAccent"
                    size: Tokens.textTitle * 1.5
                    font.weight: Font.DemiBold
                }
                Image {
                    id: face
                    anchors.fill: parent
                    anchors.margins: 2
                    // Looked up again on every lock: the picture may be new since the last.
                    source: view.hasFace ? "file://" + Quickshell.env("HOME") + "/.face?" + view.lock.lockedAt : ""
                    cache: false
                    fillMode: Image.PreserveAspectCrop
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
            order: 3
            anchors.horizontalCenter: parent.horizontalCenter
            width: hello.width; height: hello.height
            Label { id: hello; text: Lib.greeting(view.now.getHours(), view.name); size: Tokens.textLarge; font.weight: Font.DemiBold }
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
        Rise {
            order: 5
            anchors.horizontalCenter: parent.horizontalCenter
            width: notes.width; height: notes.height
            LockNotifications { id: notes; since: view.lock.lockedAt; backdrop: view.glassBackdrop; source: view.glassSource }
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
    Row {
        id: statusRow
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Tokens.islandHeight * 1.5 }
        spacing: Tokens.gap
        opacity: view.rise(7) * view.chrome
        transform: Translate { y: (1 - view.rise(7)) * Tokens.islandHeight }
        LockGlass {
            backdrop: view.glassBackdrop; source: view.glassSource
            width: netRow.implicitWidth + 2 * Tokens.padding; height: Tokens.islandHeight; radius: height / 2
            Row {
                id: netRow
                anchors.centerIn: parent
                spacing: Tokens.gap
                Icon { name: Network.kind === "wired" ? "ethernet" : Network.kind === "wifi" ? "wifi" : "network-off"; anchors.verticalCenter: parent.verticalCenter }
                Label { text: Network.online ? Network.name : "Offline"; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        LockGlass {
            visible: Power.hasBattery
            backdrop: view.glassBackdrop; source: view.glassSource
            width: batRow.implicitWidth + 2 * Tokens.padding; height: Tokens.islandHeight; radius: height / 2
            Row {
                id: batRow
                anchors.centerIn: parent
                spacing: Tokens.gap
                Icon { name: "battery"; anchors.verticalCenter: parent.verticalCenter }
                Label { text: Math.round(Power.percentage) + "%" + (Power.charging ? " · charging" : ""); numeric: true; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
    LockPower {
        backdrop: view.glassBackdrop; source: view.glassSource
        anchors { right: parent.right; bottom: parent.bottom; margins: Tokens.islandHeight * 1.5 }
        visible: Settings.get("lock.power", true)
        opacity: view.rise(8) * view.chrome
    }

    // ----------------------------------------------------------- helpers --
    // Whether there is a picture, asked on every lock (it may be new since the last).
    property bool hasFace: false
    Process {
        id: faceCheck
        command: ["test", "-r", Quickshell.env("HOME") + "/.face"]
        onExited: code => view.hasFace = code === 0
    }
    Connections { target: view.lock; function onLockedAtChanged() { faceCheck.running = true; } }
    readonly property string name: Lib.firstName(SysInfo.userRealName, SysInfo.userName || Quickshell.env("USER"))
    // How far the clock must move to sit in the middle (for ambient).
    property real clockToCentre: 0
    Connections {
        target: view.lock
        function onAmbientChanged() {
            if (view.lock.ambient) {
                const p = clock.mapToItem(view, 0, clock.height / 2);
                view.clockToCentre = view.height / 2 - p.y;
            }
        }
    }

    /// A block that rises in with the entrance; `keep` stays in ambient.
    component Rise: Item {
        property int order: 0
        property bool keep: false
        property real shiftY: 0
        opacity: view.rise(order) * (keep ? 1 - view.leave : view.chrome)
        transform: Translate { y: (1 - view.rise(order)) * Tokens.islandHeight * 0.9 + shiftY }
    }
}
