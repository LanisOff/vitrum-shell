import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components
import "../../lib/traymenu.js" as Lib

// A tray item's menu, drawn by the shell: it flows out of the tray island like
// every other panel instead of opening as a plain Qt menu. A submenu replaces
// the list in place, with a row to go back.
Column {
    id: root
    width: Tokens.islandHeight * 9
    spacing: 2

    // The menus walked into, the item's own first; back to it for every new item.
    property var stack: []
    function reset() { stack = UiState.trayItem && UiState.trayItem.hasMenu ? [UiState.trayItem.menu] : []; }
    Component.onCompleted: reset()
    Connections { target: UiState; function onTrayItemChanged() { root.reset(); } }
    readonly property bool nested: stack.length > 1
    QsMenuOpener { id: opener; menu: root.stack.length ? root.stack[root.stack.length - 1] : null }

    function back() { root.stack = root.stack.slice(0, -1); }
    function activate(entry) {
        if (!entry.enabled) return;
        if (entry.hasChildren) { root.stack = root.stack.concat([entry]); return; }
        entry.triggered();
        UiState.closePanel();
    }

    Row_ {
        visible: root.nested
        icon: "chevron"; iconRotation: 180
        text: root.nested ? Lib.label(root.stack[root.stack.length - 1].text) : ""
        dim: true
        onClicked: root.back()
    }
    Rectangle { visible: root.nested; width: root.width; height: 1; color: Colors.alpha(Colors.text, 0.1) }

    Repeater {
        model: opener.children
        delegate: Loader {
            id: slot
            required property var modelData
            width: root.width
            sourceComponent: modelData.isSeparator ? separator : entry
            Component {
                id: separator
                Item { width: root.width; height: Tokens.gap + 1
                       Rectangle { anchors.centerIn: parent; width: parent.width - 2 * Tokens.padding; height: 1; color: Colors.alpha(Colors.text, 0.1) } }
            }
            Component {
                id: entry
                Row_ {
                    readonly property string end: Lib.trailing(slot.modelData)
                    image: slot.modelData.icon || ""
                    text: Lib.label(slot.modelData.text)
                    enabled: slot.modelData.enabled
                    trailingIcon: end === "submenu" ? "chevron" : end === "check" ? "check" : ""
                    onClicked: root.activate(slot.modelData)
                }
            }
        }
    }
    Label { visible: opener.children.values.length === 0; text: "Nothing in this menu"; role: "dim"; leftPadding: Tokens.padding }

    // One menu row: an icon (theme glyph or the entry's own image), the text,
    // and an indicator at the far end. The hovered row is an accent capsule.
    component Row_: Rectangle {
        id: row
        property string icon: ""
        property real iconRotation: 0
        property string image: ""
        property string text: ""
        property string trailingIcon: ""
        property bool dim: false
        signal clicked()
        width: root.width
        height: Tokens.islandHeight
        radius: height / 2
        opacity: enabled ? 1 : 0.45
        color: hit.containsMouse && enabled ? Colors.alpha(Colors.accent, 0.22) : "transparent"
        Behavior on color { enabled: Motion.enabled; ColorAnim {} }
        Row {
            anchors { left: parent.left; leftMargin: Tokens.padding; verticalCenter: parent.verticalCenter }
            spacing: Tokens.gap
            Item {
                width: Tokens.iconSize; height: Tokens.iconSize
                anchors.verticalCenter: parent.verticalCenter
                Icon { visible: row.icon !== ""; anchors.centerIn: parent; name: row.icon; size: Tokens.iconSize; rotation: row.iconRotation
                       color: row.dim ? Colors.textDim : Colors.text }
                IconImage { visible: row.icon === "" && row.image !== ""; anchors.fill: parent; source: row.image }
            }
            Label {
                text: row.text; role: row.dim ? "dim" : "text"
                anchors.verticalCenter: parent.verticalCenter
                width: row.width - 3 * Tokens.padding - 2 * Tokens.iconSize - Tokens.gap
                elide: Text.ElideRight
            }
        }
        Icon { visible: row.trailingIcon !== ""; name: row.trailingIcon; size: Tokens.iconSize; color: Colors.textDim
               anchors { right: parent.right; rightMargin: Tokens.padding; verticalCenter: parent.verticalCenter } }
        MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; cursorShape: row.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: row.clicked() }
    }
}
