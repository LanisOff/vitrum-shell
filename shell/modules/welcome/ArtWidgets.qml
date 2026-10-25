import QtQuick
import qs.theme
import qs.components

/*
 * The tour's widgets: a clock, the weather, the system and a to-do list on
 * the wallpaper. Once, when it appears: the cards come in one after another,
 * then the editor picks the weather (its frame and resize bead light up) and
 * it grows by a step, the cards under it making room.
 */
Item {
    id: root
    readonly property real u: Tokens.islandHeight
    readonly property real cw: Math.min((width - Tokens.gap * 5) / 2, u * 6.4)
    readonly property real lx: (width - 2 * cw - Tokens.gap * 2) / 2

    property real reveal: 0
    property bool picked: false
    property real grow: 0

    Component.onCompleted: { if (Motion.enabled) demo.start(); else { reveal = 5; picked = true; grow = 1; } }
    SequentialAnimation {
        id: demo
        PauseAnimation { duration: Motion.emphasized }
        NumberAnimation { target: root; property: "reveal"; to: 5; duration: Motion.standard * 4 }
        PauseAnimation { duration: Motion.standard }
        PropertyAction { target: root; property: "picked"; value: true }
        PauseAnimation { duration: Motion.emphasized * 1.5 }
        NumberAnimation { target: root; property: "grow"; to: 1; duration: Motion.emphasized * 1.5; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.glide }
    }

    // A card's entrance: k-th in line.
    function shown(k) { const p = Math.max(0, Math.min(1, reveal - k)); return 1 - Math.pow(1 - p, 3); }

    // The clock: bare digits on the wallpaper, as the desktop clock is.
    Column {
        x: root.lx; y: Math.max(Tokens.gap * 2, root.height * 0.08)
        opacity: root.shown(0)
        scale: 0.94 + 0.06 * root.shown(0)
        transformOrigin: Item.TopLeft
        Label { text: "10:42"; numeric: true; size: Math.round(Tokens.textTitle * 2.6); font.weight: Font.Light }
        Label { text: "Sunday, 25 October"; size: Tokens.textLarge; font.weight: Font.Medium }
    }

    Grid {
        id: grid
        columns: 2
        spacing: Tokens.gap * 2
        x: root.lx
        y: Math.max(u * 4.2, root.height * 0.32)

        // The weather (the one the editor picks).
        Item {
            width: root.cw; height: Math.round(u * 4.2 + root.grow * u)
            Surface {
                id: weather
                width: parent.width; height: parent.height
                group: "widgets"; level: 0; radius: Tokens.radiusPanel
                opacity: root.shown(1)
                scale: 0.94 + 0.06 * root.shown(1)
                z: 2
                border.width: root.picked ? Math.max(2, Tokens.hairline * 2) : Tokens.hairline
                border.color: root.picked ? Colors.accent : Materials.border("widgets")
                Behavior on border.color { enabled: Motion.enabled; ColorAnim { duration: Motion.standard } }
                Column {
                    x: Tokens.padding * 1.2; y: x
                    width: weather.width - 2 * x
                    spacing: Tokens.gap / 2
                    WidgetHeader { width: parent.width; icon: "weather-partly"; title: "Weather"; trailing: "Riga" }
                    Label { text: "18°"; numeric: true; size: Math.round(Tokens.textTitle * 1.5); font.weight: Font.Light }
                    Label { text: "Partly cloudy · 21° / 12°"; role: "dim"; size: Tokens.textSmall }
                }
                // The resize bead, lit with the selection.
                Rectangle {
                    visible: root.picked
                    width: Math.round(u * 0.66); height: width; radius: Tokens.radiusKnob
                    anchors { right: parent.right; bottom: parent.bottom; margins: -Math.round(width * 0.35) }
                    color: Materials.fill("overlay", 2, Screen.name)
                    border.width: Tokens.hairline; border.color: Materials.border("overlay")
                    ShellTint { anchors.fill: parent; radius: parent.radius; group: "overlay"; active: root.picked }
                    Icon { anchors.centerIn: parent; name: "resize"; size: Tokens.textSmall; rotation: 90 }
                }
            }
        }
        // The system: two rings.
        Surface {
            width: root.cw; height: Math.round(u * 4.2)
            group: "widgets"; level: 0; radius: Tokens.radiusPanel
            opacity: root.shown(2)
            scale: 0.94 + 0.06 * root.shown(2)
            Column {
                x: Tokens.padding * 1.2; y: x
                width: parent.width - 2 * x
                spacing: Tokens.gap
                WidgetHeader { width: parent.width; icon: "cpu"; title: "System" }
                Row {
                    spacing: Tokens.gap * 1.5
                    anchors.horizontalCenter: parent.horizontalCenter
                    Repeater {
                        model: [{ v: 0.32, l: "CPU" }, { v: 0.58, l: "RAM" }]
                        delegate: Ring {
                            id: ring
                            required property var modelData
                            width: Math.round(u * 1.9); height: width
                            thickness: Math.round(width * 0.11)
                            value: modelData.v * root.shown(2)
                            Label { anchors.centerIn: parent; text: ring.modelData.l; size: Tokens.textSmall; font.weight: Font.Medium }
                        }
                    }
                }
            }
        }
        // A to-do list.
        Surface {
            width: root.cw; height: Math.round(u * 4.2)
            group: "widgets"; level: 0; radius: Tokens.radiusPanel
            opacity: root.shown(3)
            scale: 0.94 + 0.06 * root.shown(3)
            Column {
                x: Tokens.padding * 1.2; y: x
                width: parent.width - 2 * x
                spacing: Tokens.gap * 0.6
                WidgetHeader { width: parent.width; icon: "todo"; title: "Today"; trailing: "2 left" }
                Repeater {
                    model: [{ t: "Pick a wallpaper", d: true }, { t: "Try Super Space", d: false }, { t: "Call mum", d: false }]
                    delegate: Row {
                        required property var modelData
                        spacing: Tokens.gap * 0.75
                        Icon { name: parent.modelData.d ? "checkbox" : "checkbox-blank"; size: Tokens.iconSize - 2; color: parent.modelData.d ? Colors.accent : Colors.textDim; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: parent.modelData.t; size: Tokens.textSmall + 1; role: parent.modelData.d ? "dim" : "text"; font.strikeout: parent.modelData.d; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
        // Music.
        Surface {
            width: root.cw; height: Math.round(u * 4.2)
            group: "widgets"; level: 0; radius: Tokens.radiusPanel
            opacity: root.shown(4)
            scale: 0.94 + 0.06 * root.shown(4)
            Column {
                x: Tokens.padding * 1.2; y: x
                width: parent.width - 2 * x
                spacing: Tokens.gap * 0.6
                WidgetHeader { width: parent.width; icon: "music"; title: "Now playing" }
                Label { width: parent.width; text: "Night Drive"; font.weight: Font.DemiBold }
                Label { width: parent.width; text: "Glass Coast"; role: "dim"; size: Tokens.textSmall }
                Meter { width: parent.width; value: 0.4 * root.shown(4); group: "widgets" }
            }
        }
    }
}
