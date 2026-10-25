import QtQuick
import qs.theme
import qs.components

/*
 * The tour's search: Spotlight's field over the wallpaper, its keys above it.
 * Once, when it appears: a query types itself, the results come in one by
 * one, and the first one lights up.
 */
Item {
    id: root
    readonly property real u: Tokens.islandHeight
    readonly property string query: "shot"
    readonly property var results: [
        { icon: "screenshot", title: "Screenshot", sub: "App" },
        { icon: "folder", title: "Screenshots", sub: "~/Pictures" },
        { icon: "settings", title: "Screenshot settings", sub: "Settings · Capture" },
        { icon: "clipboard", title: "shot-2026-10-25.png", sub: "Clipboard" }
    ]

    property real typed: 0
    property real reveal: 0
    property bool lit: false

    Component.onCompleted: { if (Motion.enabled) demo.start(); else { typed = query.length; reveal = results.length; lit = true; } }
    SequentialAnimation {
        id: demo
        PauseAnimation { duration: Motion.emphasized * 1.5 }
        NumberAnimation { target: root; property: "typed"; to: root.query.length; duration: Motion.fast * root.query.length * 0.8 }
        PauseAnimation { duration: Motion.fast }
        NumberAnimation { target: root; property: "reveal"; to: root.results.length + 1; duration: Motion.fast * (root.results.length + 2) }
        PropertyAction { target: root; property: "lit"; value: true }
    }

    Column {
        id: col
        width: Math.min(root.width - Tokens.gap * 4, u * 13)
        x: (root.width - width) / 2
        y: Math.max(Tokens.gap * 2, root.height * 0.2)
        spacing: Tokens.gap * 1.5

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Tokens.gap / 2
            Keycap { text: "Super"; size: Tokens.textSmall; group: "launcher" }
            Keycap { text: "Space"; size: Tokens.textSmall; group: "launcher" }
        }

        Surface {
            id: field
            width: parent.width; height: Tokens.launcherHeight
            group: "launcher"; level: 0
            radius: Tokens.radiusLauncher
            Row {
                anchors { left: parent.left; leftMargin: Tokens.padding * 1.4; verticalCenter: parent.verticalCenter }
                spacing: Tokens.gap
                Icon { name: "search"; size: Tokens.iconSize + 2; color: Colors.textDim; anchors.verticalCenter: parent.verticalCenter }
                Label {
                    id: typedText
                    text: root.typed < 0.5 ? "Search" : root.query.slice(0, Math.floor(root.typed))
                    role: root.typed < 0.5 ? "dim" : "text"
                    size: Tokens.textLarge
                    anchors.verticalCenter: parent.verticalCenter
                }
                // The caret, only while it types (nothing blinks at rest).
                Rectangle {
                    visible: root.typed > 0 && root.typed < root.query.length
                    width: Tokens.hairline * 2; height: Tokens.textLarge + 2
                    color: Colors.accent
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Surface {
            width: parent.width
            height: list.implicitHeight + Tokens.gap * 2
            group: "launcher"; level: 0
            radius: Tokens.radiusPanel
            opacity: Math.min(1, root.reveal * 2)
            visible: opacity > 0
            Column {
                id: list
                x: Tokens.gap; y: Tokens.gap
                width: parent.width - 2 * x
                Repeater {
                    model: root.results
                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property real p: Math.max(0, Math.min(1, root.reveal - index))
                        readonly property real e: 1 - Math.pow(1 - p, 3)
                        width: list.width; height: Math.round(u * 1.5)
                        opacity: e
                        ShellTint {
                            anchors.fill: parent
                            radius: Tokens.radiusTile
                            group: "launcher"
                            active: row.index === 0 && root.lit
                        }
                        Row {
                            x: Tokens.padding + (1 - row.e) * Tokens.gap * 2
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Tokens.gap * 1.2
                            Icon { name: row.modelData.icon; size: Tokens.iconSize + 2; color: row.index === 0 && root.lit ? Colors.accent : Colors.text; anchors.verticalCenter: parent.verticalCenter }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Label { text: row.modelData.title; font.weight: Font.Medium }
                                Label { text: row.modelData.sub; role: "dim"; size: Tokens.textSmall }
                            }
                        }
                    }
                }
            }
        }
    }
}
