import QtQuick
import qs.theme
import qs.components

/*
 * The tour's dock: glass app squares on the plate at the bottom of the
 * wallpaper. Once, when it appears: the icons rise one after another, then
 * one app opens — its running mark shows and its window grows out of it.
 */
Item {
    id: root
    readonly property real u: Tokens.islandHeight
    readonly property int icon: Math.round(u * 1.45)
    readonly property var apps: [
        { icon: "folder", hue: 30 }, { icon: "web", hue: 200 }, { icon: "terminal", hue: -40 },
        { icon: "music", hue: 120 }, { icon: "photo", hue: 80 }, { icon: "settings", hue: 250 }
    ]

    property real rise: 0          // 0 … apps.length: how many have risen
    property real launch: 0        // the window out of the third app: 0 … 1
    property bool running: false

    Component.onCompleted: { if (Motion.enabled) demo.start(); else { rise = apps.length; running = true; launch = 1; } }
    SequentialAnimation {
        id: demo
        PauseAnimation { duration: Motion.emphasized }
        NumberAnimation { target: root; property: "rise"; to: root.apps.length + 1; duration: Motion.fast * (root.apps.length + 2) }
        PauseAnimation { duration: Motion.standard }
        PropertyAction { target: root; property: "running"; value: true }
        NumberAnimation { target: root; property: "launch"; to: 1; duration: Math.round(Motion.emphasized * 1.4); easing.type: Easing.OutQuint }
    }

    // The window that opens.
    Surface {
        id: win
        readonly property real full: Math.min(root.width - Tokens.gap * 4, u * 12)
        width: full; height: Math.min(root.height - plate.height - Tokens.gap * 6 - u, u * 10)
        x: (root.width - width) / 2
        y: plate.y - height - Tokens.gap * 2
        group: "panels"; level: 0; radius: Tokens.radiusPanel
        opacity: root.launch
        visible: opacity > 0
        scale: 0.35 + 0.65 * root.launch
        transformOrigin: Item.Bottom
        // A terminal: a prompt and a few lines.
        Column {
            x: Tokens.padding * 1.5; y: Tokens.padding * 1.5
            spacing: Tokens.gap * 0.8
            Row {
                spacing: Tokens.gap / 2
                Label { text: "~"; role: "accent"; font.family: Tokens.fontMono }
                Label { text: "fastfetch"; font.family: Tokens.fontMono }
            }
            Repeater {
                model: [0.6, 0.45, 0.7, 0.5, 0.3]
                delegate: Rectangle {
                    required property real modelData
                    width: win.width * modelData; height: Math.round(Tokens.gap * 0.8)
                    radius: Tokens.radiusMark; color: Colors.alpha(Colors.text, 0.14)
                }
            }
        }
    }

    Surface {
        id: plate
        group: "dock"
        height: root.icon + Tokens.gap * 2
        width: row.implicitWidth + Tokens.gap * 2
        radius: Math.min(Tokens.radiusPanel, height / 2)
        x: (root.width - width) / 2
        y: root.height - height - Tokens.gap * 2
        Row {
            id: row
            anchors.centerIn: parent
            spacing: Tokens.gap
            Repeater {
                model: root.apps
                delegate: Item {
                    id: slot
                    required property var modelData
                    required property int index
                    readonly property real p: Math.max(0, Math.min(1, root.rise - index))
                    readonly property real e: 1 - Math.pow(1 - p, 3)
                    width: root.icon; height: root.icon
                    // An app's icon: a square of glass, its line glyph in a
                    // tone of the wallpaper's colour.
                    Item {
                        width: parent.width; height: parent.height
                        y: (1 - slot.e) * root.icon * 0.5
                        opacity: slot.e
                        Surface {
                            anchors.fill: parent
                            group: "dock"; level: 2
                            radius: Tokens.radiusTile
                            border.color: Qt.rgba(1, 1, 1, Colors.dark ? 0.16 : 0.5)
                        }
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Tokens.hairline }
                            height: parent.height / 2
                            radius: Tokens.radiusTile
                            gradient: Gradient {
                                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, Colors.dark ? 0.12 : 0.4) }
                                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
                            }
                        }
                        Icon { anchors.centerIn: parent; name: slot.modelData.icon; size: Math.round(root.icon * 0.55); color: Colors.ink(slot.modelData.hue) }
                    }
                    // Running: a short thin mark; the app that opens, a longer one.
                    Rectangle {
                        readonly property bool on: slot.index === 1 || slot.index === 3 || (slot.index === 2 && root.running)
                        visible: on && slot.e > 0.5
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: 2 * Tokens.hairline }
                        height: 2 * Tokens.hairline; radius: Tokens.hairline
                        width: Math.round(root.icon * (slot.index === 2 ? 0.4 : 0.18))
                        color: Colors.alpha(Colors.text, 0.6)
                    }
                }
            }
        }
    }
}
