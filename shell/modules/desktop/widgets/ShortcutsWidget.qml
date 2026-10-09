import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components

// App shortcuts: options.apps (desktop ids), or the dock's pinned apps, or the most used ones.
Item {
    id: root
    property var options: ({})
    readonly property var apps: {
        const ids = options.apps || [];
        if (ids.length) return ids.map(id => Apps.forAppId(id)).filter(a => a);
        const pinned = Settings.get("dock.pinned", []).map(id => Apps.forAppId(id)).filter(a => a);
        return pinned.length ? pinned.slice(0, 6) : Apps.search("", 6);
    }
    readonly property real cell: Math.min(height, width / Math.max(1, apps.length))
    Row {
        anchors.centerIn: parent
        Repeater {
            model: root.apps
            delegate: Item {
                required property var modelData
                width: root.cell; height: root.cell
                IconImage {
                    anchors.centerIn: parent
                    implicitSize: root.cell * 0.62
                    source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                    scale: m.pressed ? 0.9 : m.containsMouse ? 1.08 : 1
                    Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.bouncy } }
                }
                MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Apps.launch(modelData) }
            }
        }
    }
}
