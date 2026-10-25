import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components

/*
 * A folder of apps on the desktop.
 *   S   a folder tile: four icons in a 2×2 grid on a square of glass, the title under it
 *   L   the header (title, how many), then the apps in a grid of four across,
 *       each with its name under it; wider sizes take more columns
 * options: title, apps (desktop file names; empty: the most used). A click launches.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "S"
    property bool preview: false
    signal optionsEdited(var options)

    readonly property bool small: sizeClass === "S"
    readonly property string title: String(options.title || "Apps")

    // ---- L: the grid's measure, from the room there is.
    readonly property int columns: Math.max(4, Math.floor(width / 80))
    readonly property real cellW: width / columns
    readonly property real iconL: Math.round(Math.min(cellW * 0.56, Tokens.iconSize * 3))
    readonly property real cellH: iconL + Tokens.textSmall * 1.6 + Tokens.gap
    readonly property int rows: Math.max(1, Math.floor((height - head.height - Tokens.gap * 0.6) / cellH))
    readonly property int wanted: small ? 4 : columns * rows

    readonly property var apps: {
        const ids = options.apps || [];
        if (ids.length) return ids.map(id => Apps.forAppId(id)).filter(a => a).slice(0, wanted);
        return Apps.search("", wanted);
    }

    function launch(app) { if (!root.preview) Apps.launch(app); }

    // ------------------------------------------------------------ S ---
    Item {
        visible: root.small
        anchors.fill: parent
        readonly property real labelH: Math.round(Tokens.textSmall * 1.7)
        Surface {
            id: tile
            readonly property real side: Math.min(root.width, root.height - parent.labelH - Tokens.gap * 0.4)
            width: side; height: side
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
            group: "widgets"
            level: 1
            radius: Tokens.radiusTile
            Grid {
                id: quad
                readonly property real pad: Math.round(tile.side * 0.13)
                readonly property real cell: (tile.side - 2 * pad - spacing) / 2
                anchors.centerIn: parent
                columns: 2
                spacing: Math.round(tile.side * 0.06)
                Repeater {
                    model: root.small ? root.apps : []
                    delegate: Item {
                        id: q
                        required property var modelData
                        width: quad.cell; height: quad.cell
                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: Math.round(quad.cell * 0.9)
                            source: Apps.iconSource(q.modelData.icon)
                            // No icon in the theme: a line glyph, not the missing texture.
                            Icon { anchors.centerIn: parent; visible: parent.source == ""; name: "window"; size: Math.round(parent.width * 0.8); color: Colors.textDim }
                            // Damped: a slight lift under the pointer, a sink when pressed.
                            scale: qm.pressed ? 0.97 : qm.containsMouse ? 1.02 : 1
                            Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }
                        }
                        MouseArea {
                            id: qm
                            anchors.fill: parent
                            enabled: !root.preview
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.launch(q.modelData)
                        }
                    }
                }
            }
        }
        Label {
            anchors { top: tile.bottom; topMargin: Tokens.gap * 0.4; horizontalCenter: parent.horizontalCenter }
            width: Math.min(implicitWidth, root.width)
            text: root.title
            size: Tokens.textSmall + 1
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // ------------------------------------------------------------ L ---
    WidgetHeader {
        id: head
        visible: !root.small
        height: visible ? implicitHeight : 0
        icon: "folder-apps"
        title: root.title
        trailing: root.apps.length ? root.apps.length + (root.apps.length === 1 ? " app" : " apps") : ""
    }
    Grid {
        visible: !root.small
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: Tokens.gap * 0.6 }
        columns: root.columns
        Repeater {
            model: root.small ? [] : root.apps
            delegate: Item {
                id: cell
                required property var modelData
                width: root.cellW; height: root.cellH
                Rectangle {
                    anchors { fill: parent; margins: 2 }
                    radius: Tokens.radiusTile
                    color: Colors.alpha(Colors.text, cm.containsMouse ? 0.07 : 0)
                    Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
                }
                IconImage {
                    id: ic
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Tokens.gap * 0.5 }
                    implicitSize: root.iconL
                    source: Apps.iconSource(cell.modelData.icon)
                    Icon { anchors.centerIn: parent; visible: parent.source == ""; name: "window"; size: Math.round(parent.width * 0.8); color: Colors.textDim }
                    scale: cm.pressed ? 0.97 : cm.containsMouse ? 1.02 : 1
                    Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }
                }
                Label {
                    anchors { top: ic.bottom; topMargin: Tokens.gap * 0.35; horizontalCenter: parent.horizontalCenter }
                    width: Math.min(implicitWidth, parent.width - 6)
                    text: cell.modelData.name
                    size: Tokens.textSmall
                    horizontalAlignment: Text.AlignHCenter
                }
                MouseArea {
                    id: cm
                    anchors.fill: parent
                    enabled: !root.preview
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.launch(cell.modelData)
                }
            }
        }
    }

    WidgetEmpty {
        visible: root.apps.length === 0 && !root.small
        icon: "apps"
        text: "No apps to show"
    }
}
