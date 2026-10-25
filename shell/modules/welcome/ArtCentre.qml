import QtQuick
import qs.theme
import qs.components

/*
 * The tour's Control Centre: the panel under the bar's right end — four
 * tiles and two sliders, Wi-Fi on. Once, when it appears: Bluetooth lights
 * up (the lit glass sweeps across it) and the volume glides up.
 */
Item {
    id: root
    readonly property real u: Tokens.islandHeight

    property bool bt: false
    property real volume: 0.28

    Component.onCompleted: { if (Motion.enabled) demo.start(); else { bt = true; volume = 0.72; } }
    SequentialAnimation {
        id: demo
        PauseAnimation { duration: Motion.emphasized * 2 }
        PropertyAction { target: root; property: "bt"; value: true }
        PauseAnimation { duration: Motion.emphasized * 1.5 }
        NumberAnimation {
            target: root; property: "volume"; to: 0.72
            duration: Motion.drift
            easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.glide
        }
    }

    // The bar's right end, where it opens from.
    Island {
        id: status
        anchors.right: parent.right; anchors.rightMargin: Tokens.gap
        y: Tokens.gap
        Repeater {
            model: ["wifi-high", root.bt ? "bluetooth-connected" : "bluetooth", "volume-high", "battery"]
            delegate: Icon { required property string modelData; name: modelData; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    Surface {
        id: panel
        group: "panels"; level: 0
        radius: Tokens.radiusPanel
        width: Math.min(root.width - Tokens.gap * 2, u * 12)
        height: col.implicitHeight + 2 * Tokens.padding * 1.2
        anchors.right: parent.right; anchors.rightMargin: Tokens.gap
        y: status.y + status.height + Tokens.gap

        Column {
            id: col
            x: Tokens.padding * 1.2; y: x
            width: panel.width - 2 * x
            spacing: Tokens.gap

            Grid {
                columns: 2
                spacing: Tokens.gap
                readonly property real cell: (col.width - spacing) / 2
                Tile { width: parent.cell; icon: "wifi-high"; title: "Wi-Fi"; subtitle: "Home"; active: true; hasMenu: true }
                Tile { width: parent.cell; icon: "bluetooth"; title: "Bluetooth"; subtitle: root.bt ? "Headphones" : "Off"; active: root.bt; hasMenu: true }
                Tile { width: parent.cell; icon: "dnd"; title: "Focus"; subtitle: "Off" }
                Tile { width: parent.cell; icon: "moon"; title: "Night light"; subtitle: "At sunset" }
            }
            Item { width: 1; height: Tokens.gap / 2 }
            Slider { width: col.width; value: root.volume; icon: "volume-high" }
            Slider { width: col.width; value: 0.6; icon: "brightness" }
        }
    }
}
