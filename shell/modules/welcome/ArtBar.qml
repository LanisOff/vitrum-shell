import QtQuick
import qs.theme
import qs.components

/*
 * The tour's bar: the three islands on the wallpaper — workspaces, the clock,
 * the status icons — and a window under them. Once, when it appears: the
 * current workspace moves two marks along, then the calendar drops from the
 * clock and today lights up. Static placeholders, no live services.
 */
Item {
    id: root
    readonly property real u: Tokens.islandHeight
    readonly property int mark: Math.round(u / 3)

    property int ws: 0
    property real cal: 0          // the calendar: 0 hidden … 1 down
    property bool today: false

    Component.onCompleted: { if (Motion.enabled) demo.start(); else { ws = 2; cal = 1; today = true; } }
    SequentialAnimation {
        id: demo
        PauseAnimation { duration: Motion.emphasized * 2 }
        PropertyAction { target: root; property: "ws"; value: 1 }
        PauseAnimation { duration: Motion.emphasized }
        PropertyAction { target: root; property: "ws"; value: 2 }
        PauseAnimation { duration: Motion.emphasized }
        NumberAnimation { target: root; property: "cal"; to: 1; duration: Motion.emphasized; easing.type: Easing.OutQuint }
        PropertyAction { target: root; property: "today"; value: true }
    }

    // A window on the workspace, to give the desktop some depth.
    Surface {
        x: Tokens.gap * 2; y: u * 2.2
        width: parent.width - 2 * x; height: Math.min(parent.height - y - Tokens.gap * 2, u * 11)
        group: "panels"; level: 0; radius: Tokens.radiusPanel
        opacity: 0.55
        Column {
            x: Tokens.padding * 1.5; y: Tokens.padding * 1.5
            spacing: Tokens.gap
            Repeater {
                model: [0.55, 0.8, 0.7, 0.4]
                delegate: Rectangle {
                    required property real modelData
                    width: root.width * 0.5 * modelData; height: Math.round(Tokens.gap * 0.9)
                    radius: Tokens.radiusMark; color: Colors.alpha(Colors.text, 0.16)
                }
            }
        }
    }

    // The bar.
    Item {
        id: bar
        x: Tokens.gap; y: Tokens.gap
        width: parent.width - 2 * x; height: u

        Island {
            anchors.left: parent.left
            Repeater {
                model: 5
                delegate: Rectangle {
                    id: m
                    required property int index
                    readonly property bool on: index === root.ws
                    height: root.mark
                    width: on ? Math.round(root.mark * 2.2) : root.mark
                    radius: Tokens.radiusMark
                    anchors.verticalCenter: parent.verticalCenter
                    color: on ? "transparent" : Colors.alpha(Colors.text, index < 3 ? 0.32 : 0.10)
                    border.width: Tokens.hairline
                    border.color: on ? "transparent" : Colors.alpha(Colors.text, index < 3 ? 0.40 : 0.22)
                    Behavior on width { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }
                    Behavior on color { enabled: Motion.enabled; ColorAnim {} }
                    ShellTint { anchors.fill: parent; radius: m.radius; group: "bar"; active: m.on }
                }
            }
        }
        Island {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            Label { text: "Sun 25"; role: "dim"; anchors.verticalCenter: parent.verticalCenter }
            Label { text: "10:42"; numeric: true; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
        }
        Island {
            anchors.right: parent.right
            Repeater {
                model: ["wifi-high", "bluetooth", "volume-high", "battery"]
                delegate: Icon { required property string modelData; name: modelData; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    // The calendar, from the clock.
    Surface {
        id: calendar
        group: "panels"; level: 0
        radius: Tokens.radiusPanel
        width: Math.round(u * 7.4)
        height: calCol.implicitHeight + 2 * Tokens.padding * 1.2
        anchors.horizontalCenter: parent.horizontalCenter
        y: bar.y + u + Tokens.gap + (1 - root.cal) * -Tokens.gap * 2
        opacity: root.cal
        visible: opacity > 0
        Column {
            id: calCol
            x: Tokens.padding * 1.2; y: x
            width: calendar.width - 2 * x
            spacing: Tokens.gap * 0.75
            Label { text: "October"; font.weight: Font.DemiBold; size: Tokens.textLarge }
            Grid {
                columns: 7
                readonly property real cell: Math.floor(calCol.width / 7)
                Repeater {
                    model: 35
                    delegate: Item {
                        id: day
                        required property int index
                        // October 2026 starts on a Thursday.
                        readonly property int n: index - 2
                        readonly property bool isToday: n === 25
                        width: parent.cell; height: Math.round(parent.cell * 0.82)
                        ShellTint {
                            anchors.centerIn: parent
                            width: parent.width - Tokens.hairline * 2; height: parent.height - Tokens.hairline * 2
                            radius: Tokens.radiusKnob
                            active: day.isToday && root.today
                        }
                        Label {
                            anchors.centerIn: parent
                            visible: day.n >= 1 && day.n <= 31
                            text: day.n
                            numeric: true
                            size: Tokens.textSmall
                            role: day.index % 7 >= 5 ? "dim" : "text"
                            font.weight: day.isToday ? Font.DemiBold : Font.Normal
                        }
                    }
                }
            }
        }
    }
}
