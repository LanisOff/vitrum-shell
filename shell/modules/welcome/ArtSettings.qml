import QtQuick
import qs.theme
import qs.components

/*
 * The tour's Settings: the window with its sidebar (Appearance chosen) and a
 * page of rows — a switch, the accent's swatches, the density. Once, when it
 * appears: the switch turns on, then the density moves to Regular.
 */
Item {
    id: root
    readonly property real u: Tokens.islandHeight

    property bool sun: false
    property int density: 0

    Component.onCompleted: { if (Motion.enabled) demo.start(); else { sun = true; density = 1; } }
    SequentialAnimation {
        id: demo
        PauseAnimation { duration: Motion.emphasized * 2 }
        PropertyAction { target: root; property: "sun"; value: true }
        PauseAnimation { duration: Motion.emphasized * 2 }
        PropertyAction { target: root; property: "density"; value: 1 }
    }

    Surface {
        id: win
        group: "panels"; level: 0
        radius: Tokens.radiusPanel
        width: Math.min(root.width - Tokens.gap * 2, u * 15)
        height: Math.min(root.height - Tokens.gap * 4, Math.max(side.implicitHeight, page.implicitHeight) + Tokens.padding * 3)
        x: (root.width - width) / 2
        y: Math.max(Tokens.gap * 2, (root.height - height) * 0.4)

        // The sidebar.
        Column {
            id: side
            x: Tokens.gap; y: Tokens.padding * 1.5
            width: Math.round(u * 4.6)
            spacing: Tokens.hairline * 2
            Repeater {
                model: [{ i: "palette", l: "Appearance" }, { i: "image", l: "Wallpaper" }, { i: "screen", l: "Displays" },
                        { i: "speaker", l: "Sound" }, { i: "keyboard", l: "Keyboard" }, { i: "apps", l: "Apps" }]
                delegate: Item {
                    id: item
                    required property var modelData
                    required property int index
                    width: side.width; height: Math.round(u * 1.1)
                    ShellTint { anchors.fill: parent; radius: Tokens.radiusButton; active: item.index === 0 }
                    Row {
                        x: Tokens.gap; anchors.verticalCenter: parent.verticalCenter
                        spacing: Tokens.gap
                        Icon { name: item.modelData.i; size: Tokens.iconSize - 1; color: item.index === 0 ? Colors.accent : Colors.text; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: item.modelData.l; size: Tokens.textSmall + 1; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
        Rectangle {
            x: side.x + side.width + Tokens.gap; y: Tokens.gap
            width: Tokens.hairline; height: parent.height - 2 * y
            color: Colors.alpha(Colors.text, 0.08)
        }

        // The page.
        Column {
            id: page
            x: side.x + side.width + Tokens.gap * 2.5; y: Tokens.padding * 1.5
            width: win.width - x - Tokens.padding * 1.5
            spacing: Tokens.gap * 1.2

            Label { text: "Appearance"; size: Tokens.textLarge + 2; font.weight: Font.DemiBold }

            Surface {
                width: parent.width; height: rows.implicitHeight
                group: "panels"; level: 1; radius: Tokens.radiusTile
                Column {
                    id: rows
                    width: parent.width
                    // A setting: the name, a dim line under it, the control at the end.
                    Item {
                        width: parent.width; height: Math.round(u * 1.6)
                        Column {
                            x: Tokens.padding; anchors.verticalCenter: parent.verticalCenter
                            Label { text: "Follow the sun"; size: Tokens.textSmall + 1; font.weight: Font.Medium }
                            Label { text: "Light by day, dark at night"; role: "dim"; size: Tokens.textSmall }
                        }
                        GlassSwitch { anchors.right: parent.right; anchors.rightMargin: Tokens.padding; anchors.verticalCenter: parent.verticalCenter; checked: root.sun }
                    }
                    Rectangle { x: Tokens.padding; width: parent.width - 2 * x; height: Tokens.hairline; color: Colors.alpha(Colors.text, 0.07) }
                    Item {
                        width: parent.width; height: Math.round(u * 1.6)
                        Label { x: Tokens.padding; anchors.verticalCenter: parent.verticalCenter; text: "Accent"; size: Tokens.textSmall + 1; font.weight: Font.Medium }
                        Row {
                            anchors { right: parent.right; rightMargin: Tokens.padding; verticalCenter: parent.verticalCenter }
                            spacing: Tokens.gap / 2
                            Repeater {
                                model: [0, 60, 150, -60]
                                delegate: GlassChoice {
                                    required property int modelData
                                    required property int index
                                    width: Math.round(u * 0.95); height: width
                                    swatch: Colors.tone(modelData, Colors.dark ? 0.22 : 0)
                                    chosen: index === 0
                                }
                            }
                        }
                    }
                }
            }

            Label { text: "Density"; size: Tokens.textSmall + 1; font.weight: Font.Medium; role: "dim" }
            Row {
                spacing: Tokens.gap / 2
                Repeater {
                    model: ["Compact", "Regular", "Large"]
                    delegate: GlassChoice {
                        required property string modelData
                        required property int index
                        label: modelData
                        chosen: index === root.density
                    }
                }
            }
        }
    }
}
