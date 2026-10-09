import QtQuick
import qs.services
import qs.theme
import qs.components

/*
 * A piece of the lock in its material: liquid glass over the lock's own
 * wallpaper (Glass — niri draws nothing under a locked session), or a solid
 * fill when the lock group is solid. Children sit on top.
 *
 *   backdrop, source   LockView's backdrop and its texture
 *   tint               the glass's colour (a wrong password turns it red)
 */
Item {
    id: pane
    property Item backdrop: null
    property Item source: null
    property real radius: Tokens.radiusPanel
    property color tint: Qt.rgba(1, 1, 1, Colors.dark ? 0.07 : 0.16)
    property real edgeLight: 0.5
    property color outline: Colors.alpha(Colors.text, 0.12)
    default property alias content: inner.data

    readonly property string material: Materials.of("lock")

    Glass {
        anchors.fill: parent
        visible: pane.material !== "solid"
        backdrop: pane.backdrop
        source: pane.source
        bevel: Math.min(18, pane.height * 0.35)
        // Frosted: the same pane, barely bending what is behind.
        refraction: pane.material === "glass" ? Math.min(26, pane.height * 0.45) : 5
        edgeLight: pane.edgeLight
        tint: pane.material === "glass" ? pane.tint : Qt.tint(Colors.alpha(Colors.surface, 0.45), pane.tint)
        Rectangle { anchors.fill: parent; radius: pane.radius }
    }
    Rectangle {
        anchors.fill: parent
        visible: pane.material === "solid"
        radius: pane.radius
        color: Qt.tint(Materials.fill("lock", 0), pane.tint)
    }
    Rectangle {
        anchors.fill: parent
        radius: pane.radius
        color: "transparent"
        border.width: Tokens.hairline
        border.color: pane.outline
    }
    Item { id: inner; anchors.fill: parent }
}
