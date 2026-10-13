import QtQuick
import qs.services
import qs.theme
import qs.components
import "../../../lib/widgets.js" as W

/*
 * This month.
 *   S   today's date big, the weekday over it, the month under it
 *   L   the header (month, year); the weekday initials; six weeks of days,
 *       today in an accent circle, the neighbours' days dim; ISO week numbers
 *       down the left when asked for
 * options: firstDay ("1" Monday, "0" Sunday), weekNumbers.
 * A free size too short for the grid shows the S glance.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "L"
    property bool preview: false
    signal optionsEdited(var options)

    property date today: new Date()
    // Once a minute is plenty to roll over at midnight.
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.today = new Date() }

    readonly property bool glance: sizeClass === "S" || sizeClass === "M"
    readonly property int first: options.firstDay === "0" ? 0 : 1
    readonly property bool weeks: options.weekNumbers === true
    readonly property var grid: W.monthGrid(today.getFullYear(), today.getMonth(), first)

    // ISO 8601: the week that holds the row's Thursday.
    function isoWeek(y, m, d) {
        const t = new Date(Date.UTC(y, m, d));
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
        const start = Date.UTC(t.getUTCFullYear(), 0, 1);
        return Math.ceil(((t - start) / 86400000 + 1) / 7);
    }

    // ---- S: one glance.
    Column {
        visible: root.glance
        anchors.centerIn: parent
        spacing: 0
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.today, "dddd")
            role: "accent"; size: Tokens.textSmall + 1; font.weight: Font.Medium
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.today.getDate()
            numeric: true; font.weight: Font.Light
            size: Math.round(Math.min(root.height * 0.5, root.width * 0.42))
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.today, "MMMM")
            role: "dim"; size: Tokens.textSmall
        }
    }

    // ---- L: the month.
    WidgetHeader {
        id: head
        visible: !root.glance
        icon: "calendar"
        title: Qt.formatDate(root.today, "MMMM")
        trailing: Qt.formatDate(root.today, "yyyy")
    }
    Item {
        id: month
        visible: !root.glance
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; topMargin: Tokens.gap * 0.6 }
        readonly property int cols: root.weeks ? 8 : 7
        readonly property real cellW: width / cols
        readonly property real cellH: (height - names.height) / 6
        readonly property real dot: Math.min(cellW, cellH) * 0.86

        Row {
            id: names
            height: Tokens.textSmall * 1.8
            Item { visible: root.weeks; width: month.cellW; height: 1 }
            Repeater {
                model: 7
                delegate: Label {
                    required property int index
                    width: month.cellW; height: names.height
                    horizontalAlignment: Text.AlignHCenter
                    role: "dim"; size: Tokens.textSmall; font.weight: Font.Medium
                    text: Qt.locale().dayName((root.first + index) % 7, Locale.NarrowFormat)
                }
            }
        }
        Column {
            anchors.top: names.bottom
            Repeater {
                model: 6
                delegate: Row {
                    id: week
                    required property int index
                    readonly property var days: root.grid.slice(index * 7, index * 7 + 7)
                    // The row's Monday decides its ISO week.
                    readonly property var monday: days[root.first === 1 ? 0 : 1]
                    Label {
                        visible: root.weeks
                        width: month.cellW; height: month.cellH
                        horizontalAlignment: Text.AlignHCenter
                        numeric: true; role: "dim"; size: Tokens.textSmall - 1
                        opacity: 0.75
                        text: week.monday ? root.isoWeek(week.monday.year, week.monday.month, week.monday.day) : ""
                    }
                    Repeater {
                        model: week.days
                        delegate: Item {
                            required property var modelData
                            readonly property bool isToday: modelData.inMonth && modelData.day === root.today.getDate()
                            width: month.cellW; height: month.cellH
                            Rectangle {
                                anchors.centerIn: parent
                                width: month.dot; height: width; radius: width / 2
                                color: Colors.accent
                                visible: parent.isToday
                            }
                            Label {
                                anchors.centerIn: parent
                                text: modelData.day
                                numeric: true
                                size: Math.max(Tokens.textSmall, Math.round(month.dot * 0.42))
                                font.weight: parent.isToday ? Font.DemiBold : Font.Normal
                                color: parent.isToday ? Colors.onAccent : Colors.text
                                opacity: modelData.inMonth ? 1 : 0.32
                            }
                        }
                    }
                }
            }
        }
    }
}
