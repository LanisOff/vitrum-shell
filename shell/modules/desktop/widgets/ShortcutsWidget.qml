import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components

/*
 * Apps a click away.
 *   S   four icons, two by two
 *   M   the header; up to five icons in a row, their names under them
 * options: apps (desktop ids); empty: the Dock's pinned apps, or the most used.
 * A click launches (Apps.launch); a gallery card shows them and launches nothing.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    readonly property bool small: sizeClass === "S"
    readonly property int limit: small ? 4 : 5
    readonly property var apps: {
        const ids = options.apps || [];
        let list = ids.map(id => Apps.forAppId(String(id).replace(/\.desktop$/, ""))).filter(a => a);
        if (!ids.length) {
            list = Settings.get("dock.pinned", []).map(id => Apps.forAppId(id)).filter(a => a);
            if (!list.length) list = Apps.search("", root.limit);
        }
        return list.slice(0, root.limit);
    }

    WidgetHeader {
        id: head
        visible: !root.small
        height: visible ? implicitHeight : 0
        icon: "apps"; title: "Shortcuts"
    }
    WidgetEmpty {
        visible: root.apps.length === 0
        icon: "apps"
        text: "Add apps in the widget's options"
    }

    // ---- S: two by two. M: one row, names under.
    Grid {
        id: grid
        visible: root.apps.length > 0
        readonly property real areaH: root.height - (head.visible ? head.height + Tokens.gap * 0.6 : 0)
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
        height: areaH
        columns: root.small ? 2 : root.limit
        readonly property real cellW: root.small ? root.width / 2 : root.width / root.limit
        readonly property real cellH: root.small ? areaH / 2 : areaH
        readonly property real icon: Math.min(cellW, root.small ? cellH : cellH - Tokens.textSmall * 1.8) * 0.66
        Repeater {
            model: root.apps
            delegate: Item {
                id: cell
                required property var modelData
                width: grid.cellW; height: grid.cellH
                Rectangle {
                    // A faint lift under the hovered one.
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) * 0.94; height: root.small ? width : parent.height * 0.96
                    radius: Tokens.radiusTile
                    color: Colors.alpha(Colors.text, mouse.containsMouse ? 0.08 : 0)
                    Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
                }
                Column {
                    anchors.centerIn: parent
                    spacing: Tokens.gap * 0.3
                    IconImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitSize: grid.icon
                        source: Apps.iconSource(cell.modelData.icon)
                        // No icon in the theme: a line glyph, not the missing texture.
                        Icon { anchors.centerIn: parent; visible: parent.source == ""; name: "window"; size: Math.round(parent.width * 0.8); color: Colors.textDim }
                        // Damped: a slight lift under the pointer, a sink when pressed.
                        scale: mouse.pressed ? 0.97 : mouse.containsMouse ? 1.02 : 1
                        Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }
                    }
                    Label {
                        visible: !root.small
                        width: grid.cellW - Tokens.gap * 0.5
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.name
                        size: Tokens.textSmall
                    }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    enabled: !root.preview
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Apps.launch(cell.modelData)
                }
            }
        }
    }
}
