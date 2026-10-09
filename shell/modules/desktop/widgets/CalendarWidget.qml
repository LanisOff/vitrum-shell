import QtQuick
import qs.theme
import qs.components
import "../../../lib/widgets.js" as W

// This month, weeks from the locale's first day; today in the accent.
Item {
    id: root
    property var options: ({})
    property date today: new Date()
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.today = new Date() }
    readonly property int first: Qt.locale().firstDayOfWeek % 7
    readonly property var grid: W.monthGrid(today.getFullYear(), today.getMonth(), first)
    readonly property real cell: Math.min(width / 7, (height - head.height - names.height - 4) / 6)

    WidgetHeader { id: head; icon: "calendar"; title: Qt.formatDate(root.today, "MMMM"); trailing: Qt.formatDate(root.today, "yyyy"); hue: 330 }
    Row {
        id: names
        anchors.top: head.bottom; anchors.topMargin: 4
        x: (root.width - 7 * root.cell) / 2
        Repeater {
            model: 7
            delegate: Label { required property int index; width: root.cell; horizontalAlignment: Text.AlignHCenter; role: "dim"; size: Tokens.textSmall
                              text: Qt.locale().dayName((root.first + index) % 7, Locale.NarrowFormat) }
        }
    }
    Grid {
        anchors.top: names.bottom
        x: (root.width - 7 * root.cell) / 2
        columns: 7
        Repeater {
            model: root.grid
            delegate: Item {
                required property var modelData
                readonly property bool isToday: modelData.inMonth && modelData.day === root.today.getDate()
                width: root.cell; height: root.cell
                Rectangle { anchors.centerIn: parent; width: parent.width * 0.84; height: width; radius: width / 2; color: Colors.accent; visible: parent.isToday }
                // Only this month: the neighbours' days were noise.
                Label { anchors.centerIn: parent; visible: modelData.inMonth; text: modelData.day; numeric: true
                        size: Math.max(Tokens.textSmall, root.cell * 0.36)
                        font.weight: parent.isToday ? Font.Bold : Font.Normal
                        color: parent.isToday ? Colors.onAccent : Colors.text }
            }
        }
    }
}
