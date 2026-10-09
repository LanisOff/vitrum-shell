import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components
import qs.common
import "../lib/widgets.js" as W

Page {
    id: page
    title: "Widgets"
    subtitle: "Widgets live on the desktop, per screen. Arrange them on the desktop itself."
    readonly property var items: Settings.get("widgets.items", []) || []
    Section {
        SettingRow {
            label: "Arrange on the desktop"; hint: "Drag to move, the corner to resize, × to remove. Also Mod+Alt+W."; divider: false
            Chip_ { text: "Edit widgets"; accent: true; onClicked: Quickshell.execDetached(["vitrum-ipc", "widgets", "edit"]) }
        }
    }
    Section {
        title: "Add to the focused screen"
        Flow {
            width: parent.width; padding: Tokens.padding; spacing: Tokens.gap / 2
            Repeater {
                model: W.types()
                delegate: Chip_ { required property string modelData; text: modelData.charAt(0).toUpperCase() + modelData.slice(1); onClicked: Quickshell.execDetached(["vitrum-ipc", "widgets", "add", modelData]) }
            }
        }
    }
    Section {
        title: "On the desktop"
        Label { visible: page.items.length === 0; text: "No widgets yet."; role: "dim"; padding: Tokens.padding }
        Repeater {
            model: page.items
            delegate: SettingRow {
                required property var modelData
                required property int index
                label: (modelData.type || "?").charAt(0).toUpperCase() + (modelData.type || "?").slice(1)
                hint: (modelData.output || "?") + " · " + Math.round(modelData.x || 0) + ", " + Math.round(modelData.y || 0) + " · " + Math.round(modelData.w || 0) + "×" + Math.round(modelData.h || 0)
                Icon { name: "close"; anchors.verticalCenter: parent.verticalCenter
                       MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const l = page.items.slice(); l.splice(index, 1); Settings.set("widgets.items", l); } } }
            }
        }
    }
    component Chip_: Rectangle {
        id: c
        property string text: ""
        property bool accent: false
        signal clicked()
        height: Tokens.islandHeight * 1.05; radius: height / 2; width: cl.implicitWidth + Tokens.padding * 1.6
        color: accent ? Colors.accent : cm.containsMouse ? Colors.alpha(Colors.text, 0.12) : Colors.alpha(Colors.text, 0.06)
        Label { id: cl; anchors.centerIn: parent; text: c.text; role: c.accent ? "onAccent" : "text" }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: c.clicked() }
    }
}
