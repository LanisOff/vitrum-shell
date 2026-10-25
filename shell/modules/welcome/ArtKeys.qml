import QtQuick
import qs.theme
import qs.components

/*
 * The tour's keybind sheet: its title and search field, and binds as rows of
 * caps. Once, when it appears: the rows come in one by one, then "shot" types
 * itself into the search and the rows that do not match fold away.
 */
Item {
    id: root
    readonly property real u: Tokens.islandHeight
    readonly property string query: "shot"
    readonly property var binds: [
        { l: "Search", k: ["Super", "Space"] },
        { l: "Control Centre", k: ["Super", "Alt", "C"] },
        { l: "Region screenshot", k: ["Super", "Shift", "S"] },
        { l: "Close window", k: ["Super", "Q"] },
        { l: "Screenshot this screen", k: ["Ctrl", "Print"] },
        { l: "Settings", k: ["Super", ","] },
        { l: "Lock screen", k: ["Super", "Alt", "L"] }
    ]

    property real reveal: 0
    property real typed: 0
    readonly property string shownQuery: query.slice(0, Math.floor(typed))
    // Filtered once the whole query is in.
    function matches(b) { return shownQuery.length < query.length || b.l.toLowerCase().indexOf(query) >= 0; }

    Component.onCompleted: { if (Motion.enabled) demo.start(); else { reveal = binds.length; typed = query.length; } }
    SequentialAnimation {
        id: demo
        PauseAnimation { duration: Motion.emphasized }
        NumberAnimation { target: root; property: "reveal"; to: root.binds.length + 1; duration: Motion.fast * (root.binds.length + 2) * 0.7 }
        PauseAnimation { duration: Motion.emphasized * 1.5 }
        NumberAnimation { target: root; property: "typed"; to: root.query.length; duration: Motion.fast * root.query.length * 0.8 }
    }

    Surface {
        id: sheet
        group: "overlay"; level: 0
        radius: Tokens.radiusPanel
        width: Math.min(root.width - Tokens.gap * 2, u * 14)
        // Measured, not taken from the column: the rows fold to nothing.
        readonly property real rowH: Math.round(u * 1.25)
        readonly property int rows: root.binds.filter(b => root.matches(b)).length
        height: Tokens.padding * 3 + Math.round(u * 1.2) + Tokens.gap + rows * rowH
        x: (root.width - width) / 2
        y: Math.max(Tokens.gap * 2, root.height * 0.1)
        Behavior on height { enabled: Motion.enabled; NumberAnimation { duration: Motion.standard; easing.type: Easing.OutCubic } }

        Column {
            id: col
            x: Tokens.padding * 1.5; y: x
            width: sheet.width - 2 * x
            spacing: Tokens.gap

            Item {
                width: parent.width; height: Math.round(u * 1.2)
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.gap
                    Icon { name: "keyboard"; size: Tokens.iconSize + 2; anchors.verticalCenter: parent.verticalCenter }
                    Label { text: "Keybinds"; size: Tokens.textLarge; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                }
                Surface {
                    group: "overlay"; level: 1; outlined: false
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: Math.round(parent.width * 0.42); height: parent.height
                    radius: Tokens.radiusTile
                    Row {
                        x: Tokens.gap; anchors.verticalCenter: parent.verticalCenter
                        spacing: Tokens.gap * 0.75
                        Icon { name: "search"; size: Tokens.iconSize - 2; color: Colors.textDim; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: root.shownQuery || "Filter"; role: root.shownQuery ? "text" : "dim"; size: Tokens.textSmall + 1; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }

            Column {
                width: parent.width
                Repeater {
                    model: root.binds
                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property real p: Math.max(0, Math.min(1, root.reveal - index))
                        readonly property real e: 1 - Math.pow(1 - p, 3)
                        readonly property bool match: root.matches(modelData)
                        width: parent.width
                        height: match ? sheet.rowH : 0
                        opacity: match ? e : 0
                        visible: height > 0.5
                        clip: true
                        Behavior on height { enabled: Motion.enabled; NumberAnimation { duration: Motion.standard; easing.type: Easing.OutCubic } }
                        Behavior on opacity { enabled: Motion.enabled && root.typed > 0; EaseAnim { duration: Motion.fast } }
                        Label {
                            x: (1 - row.e) * Tokens.gap * 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.l
                            size: Tokens.textSmall + 1
                        }
                        Row {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            spacing: Tokens.hairline * 3
                            Repeater {
                                model: row.modelData.k
                                delegate: Keycap { required property string modelData; text: modelData; size: Tokens.textSmall - 1 }
                            }
                        }
                    }
                }
            }
        }
    }
}
