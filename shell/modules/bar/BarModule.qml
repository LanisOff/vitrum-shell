import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components

/*
 * Base of every bar module: knows its screen and island, hides itself with
 * `shown`, and opens `panel` (if any) out of its island on click.
 */
Item {
    id: root
    property var screen: null
    property bool primary: false
    property Item island: null
    property bool shown: true
    property string panel: ""
    property bool hoverable: true
    readonly property bool hovered: mouse.containsMouse
    signal clicked(var mouse)
    signal wheel(var wheel)

    implicitHeight: Tokens.islandHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    function openPanel() {
        if (!panel) return;
        const src = island || root;
        const p = src.mapToItem(null, 0, 0);
        UiState.openPanel(panel, screen, Qt.rect(p.x, p.y, src.width, src.height), island);
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: root.hoverable
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => { root.clicked(m); if (m.button === Qt.LeftButton) root.openPanel(); }
        onWheel: w => root.wheel(w)
        z: -1
    }
}
