import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.components

/*
 * The colour picker over one screen: its frozen picture, a loupe (pixels,
 * 12× at the pointer) with the colour and its hex, and the recent colours.
 * Click copies hex, Shift+click rgb(); arrows nudge a pixel; Esc cancels.
 */
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    visible: ColorPick.active
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "vitrum-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible && screen.name === (Niri.focusedOutput || Quickshell.screens[0].name) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property real px: width / 2
    property real py: height / 2
    property string hex: "#000000"
    readonly property real dpr: canvas.loaded ? canvas.imgW / Math.max(1, width) : 1

    // The frozen picture, shown and read.
    Image { id: shot; anchors.fill: parent; source: root.visible ? ColorPick.frozen(root.screen.name) + "?" + ColorPick.stamp : ""; cache: false; smooth: false }
    Canvas {
        id: canvas
        visible: false
        width: 1; height: 1
        property bool loaded: false
        property real imgW: 1
        readonly property string src: shot.source.toString()
        onSrcChanged: { loaded = false; if (src) loadImage(src); }
        onImageLoaded: {
            const ctx = getContext("2d");
            const img = ctx.createImageData(src);
            imgW = img.width;
            width = img.width; height = img.height;
            requestPaint();
        }
        onPaint: {
            if (!src || !isImageLoaded(src)) return;
            const ctx = getContext("2d");
            ctx.drawImage(src, 0, 0);
            loaded = true;
            root.sample();
        }
    }
    function sample() {
        if (!canvas.loaded) return;
        const d = canvas.getContext("2d").getImageData(Math.floor(px * dpr), Math.floor(py * dpr), 1, 1).data;
        const h = n => (n < 16 ? "0" : "") + n.toString(16);
        hex = "#" + h(d[0]) + h(d[1]) + h(d[2]);
    }
    onPxChanged: sample()
    onPyChanged: sample()

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.CrossCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPositionChanged: m => { root.px = m.x; root.py = m.y; }
        onClicked: m => { if (m.button === Qt.RightButton) ColorPick.cancel(); else ColorPick.pick(root.hex, m.modifiers & Qt.ShiftModifier); }
    }
    Item {
        focus: root.visible
        Keys.onEscapePressed: ColorPick.cancel()
        Keys.onReturnPressed: ColorPick.pick(root.hex, false)
        Keys.onLeftPressed: root.px = Math.max(0, root.px - 1 / root.dpr)
        Keys.onRightPressed: root.px = Math.min(root.width - 1, root.px + 1 / root.dpr)
        Keys.onUpPressed: root.py = Math.max(0, root.py - 1 / root.dpr)
        Keys.onDownPressed: root.py = Math.min(root.height - 1, root.py + 1 / root.dpr)
    }

    // The loupe: the pixels around the pointer, big, with the one picked framed.
    Item {
        id: loupe
        readonly property int cells: 11
        readonly property real cell: 12
        width: cells * cell; height: width + label.height + Tokens.gap
        x: Math.min(root.width - width - 16, root.px + 24)
        y: Math.min(root.height - height - 16, root.py + 24)
        Rectangle {
            id: lens
            width: parent.width; height: width; radius: Tokens.radiusInner * 1.5; clip: true
            color: "black"
            Image {
                source: shot.source
                smooth: false
                cache: false
                sourceClipRect: Qt.rect(Math.floor(root.px * root.dpr) - Math.floor(loupe.cells / 2), Math.floor(root.py * root.dpr) - Math.floor(loupe.cells / 2), loupe.cells, loupe.cells)
                width: lens.width; height: lens.height
            }
            Rectangle {
                anchors.centerIn: parent; width: loupe.cell; height: loupe.cell
                color: "transparent"; border.width: 2; border.color: "white"
                Rectangle { anchors.fill: parent; anchors.margins: -1; color: "transparent"; border.width: 1; border.color: "black" }
            }
        }
        // The rim, in the colour under the pointer (over the pixels, not under them).
        Rectangle {
            width: lens.width; height: lens.height; radius: lens.radius
            color: "transparent"; border.width: 4; border.color: root.hex
            Rectangle { anchors.fill: parent; anchors.margins: -1; radius: parent.radius + 1; color: "transparent"; border.width: 1; border.color: Colors.alpha("#000000", 0.4) }
        }
        Surface {
            id: label
            group: "overlay"
            anchors { top: lens.bottom; topMargin: Tokens.gap; horizontalCenter: lens.horizontalCenter }
            width: row.implicitWidth + 2 * Tokens.padding; height: Tokens.islandHeight
            radius: height / 2
            Row {
                id: row
                anchors.centerIn: parent
                spacing: Tokens.gap
                Rectangle { width: Tokens.iconSize; height: width; radius: width / 2; color: root.hex; border.width: 1; border.color: Colors.alpha(Colors.text, 0.3); anchors.verticalCenter: parent.verticalCenter }
                Label { text: root.hex.toUpperCase(); numeric: true; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    // Recent colours: a click copies one again.
    Surface {
        visible: ColorPick.history.length > 0
        group: "overlay"
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Tokens.islandHeight * 2 }
        width: hist.implicitWidth + 2 * Tokens.padding; height: Tokens.islandHeight * 1.4
        radius: height / 2
        Row {
            id: hist
            anchors.centerIn: parent
            spacing: Tokens.gap
            Label { text: "Click copies · Shift rgb() · Esc"; role: "dim"; size: Tokens.textSmall; anchors.verticalCenter: parent.verticalCenter }
            Repeater {
                model: ColorPick.history
                Rectangle {
                    required property string modelData
                    width: Tokens.islandHeight * 0.8; height: width; radius: width / 2
                    color: modelData; border.width: 1; border.color: Colors.alpha(Colors.text, 0.3)
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ColorPick.copy(modelData); ColorPick.cancel(); } }
                }
            }
        }
    }
}
