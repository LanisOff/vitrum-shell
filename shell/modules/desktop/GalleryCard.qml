import QtQuick
import qs.services
import qs.theme
import qs.components
import "../../lib/widgets.js" as W

/*
 * One widget in the editor's gallery: the real widget, live, shrunk into the
 * card (preview: true — sample data where it would have to ask for more),
 * its name and the sizes it comes in. A click adds it; dragged out of the
 * sheet it lands where it is let go (windowPos: the window's coordinates).
 */
Rectangle {
    id: card
    property string type: ""
    readonly property var meta: W.meta(type, WidgetEditor.custom)
    signal clicked()
    signal dragged(point windowPos)
    signal dropped(point windowPos)

    radius: Tokens.radiusPanel
    color: mouse.containsMouse ? Colors.alpha(Colors.text, Colors.dark ? 0.1 : 0.07) : Colors.alpha(Colors.text, Colors.dark ? 0.055 : 0.04)
    Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
    scale: mouse.pressed && !mouse.dragging ? 0.97 : 1
    Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }

    // The preview: the widget at its default size, scaled into the box, on its plate.
    Item {
        id: box
        x: 8; y: 8
        width: parent.width - 16
        height: parent.height - 16 - foot.height
        readonly property var size: W.presetSize(card.meta.def)
        readonly property real k: Math.min(width / size.w, height / size.h)
        Item {
            width: box.size.w; height: box.size.h
            anchors.centerIn: parent
            scale: box.k
            Surface {
                anchors.fill: parent
                visible: !(card.type === "clock")
                group: "widgets"
                radius: Tokens.radiusPanel * 1.25
            }
            Loader {
                id: preview
                anchors.fill: parent
                anchors.margins: card.type === "clock" ? 0 : Tokens.padding
                enabled: false
                asynchronous: true
                source: W.widgetFile(card.type) ? Qt.resolvedUrl("widgets/" + W.widgetFile(card.type)) : ""
                onLoaded: {
                    item.options = W.withDefaults(card.type, {}, WidgetEditor.custom);
                    if (item.hasOwnProperty("sizeClass")) item.sizeClass = card.meta.def;
                    if (item.hasOwnProperty("preview")) item.preview = true;
                    if (item.hasOwnProperty("type")) item.type = card.type;
                }
            }
            WidgetEmpty { visible: preview.status === Loader.Error; icon: card.meta.icon; text: card.meta.name }
        }
    }
    Row {
        id: foot
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10 }
        height: Tokens.textSize * 1.6
        spacing: 6
        Icon { name: card.meta.icon; size: Tokens.textSize + 2; color: Colors.accent2; anchors.verticalCenter: parent.verticalCenter }
        Label { width: parent.width - sizes.width - Tokens.textSize - 14; text: card.meta.name; font.weight: Font.Medium; size: Tokens.textSmall + 1; anchors.verticalCenter: parent.verticalCenter }
        Label { id: sizes; text: card.meta.sizes.join(" "); role: "dim"; size: Tokens.textSmall - 1; anchors.verticalCenter: parent.verticalCenter }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        property point start
        property bool dragging: false
        property bool wasDrag: false            // the click after a drag is no click
        onPressed: m => { start = Qt.point(m.x, m.y); dragging = false; wasDrag = false; }
        onPositionChanged: m => {
            if (!pressed) return;
            if (!dragging && Math.hypot(m.x - start.x, m.y - start.y) > 8) { dragging = true; WidgetEditor.dragType = card.type; }
            if (dragging) card.dragged(mapToItem(null, m.x, m.y));
        }
        onReleased: m => {
            if (dragging) { card.dropped(mapToItem(null, m.x, m.y)); WidgetEditor.dragType = ""; dragging = false; wasDrag = true; }
        }
        onClicked: if (!wasDrag) card.clicked()
        onCanceled: { WidgetEditor.dragType = ""; dragging = false; }
    }
}
