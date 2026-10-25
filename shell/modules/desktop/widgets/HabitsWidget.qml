import QtQuick
import qs.services
import qs.theme
import qs.components
import "../../../lib/habits.js" as Lib

/*
 * Habits: a row of the last seven days per habit, each day a square of glass,
 * lit when it was done, and the streak of days in a row at the end.
 *   S   how many are done today, big; under it each habit with today's square
 *   M   the header (done today); a row per habit: its name, the week, the streak
 *   L   the same under a line of the weekdays' initials
 * A click on a square turns that day on or off (today's is outlined).
 * The habits are named in the options (a chip renamed in place keeps its
 * days); the days live in the hidden `marks` (lib/habits.js), as the To-do's
 * items do. Midnight moves the week on.
 * options: habits (names), streak (show the streak); marks (hidden).
 * In a gallery card a sample week stands in, and nothing is saved.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    property date today: new Date()
    // To the next midnight, then again: the week moves on with the date.
    Timer {
        id: midnight
        running: !root.preview
        repeat: false
        interval: {
            const t = root.today;
            return Math.max(1000, new Date(t.getFullYear(), t.getMonth(), t.getDate() + 1, 0, 0, 2).getTime() - Date.now());
        }
        onTriggered: { root.today = new Date(); restart(); }
    }

    readonly property var sampleHabits: ["Read", "Walk", "Water"]
    function sampleMarks() {
        const w = Lib.week({}, today, 7).map(d => d.key);
        return ["Read\t" + [w[0], w[1], w[2], w[4], w[5], w[6]].join(" "),
                "Walk\t" + [w[1], w[3], w[5]].join(" "),
                "Water\t" + w.join(" ")];
    }
    readonly property var habitNames: preview ? sampleHabits : (options.habits || [])
    // A local copy, so a click shows at once, before the saved options come back.
    property var marks: []
    function load() {
        today = new Date();
        marks = preview ? sampleMarks() : (options.marks || []).slice();
    }
    onOptionsChanged: load()
    onPreviewChanged: load()
    Component.onCompleted: load()

    readonly property var list: Lib.resolve(habitNames, marks)
    readonly property var rows: list.map((h, i) => ({ i: i, name: h.name, week: Lib.week(h.days, today, 7), streak: Lib.streak(h.days, today) }))
    readonly property int doneToday: rows.filter(r => r.week[6].done).length
    readonly property bool showStreak: options.streak !== false

    function toggle(i, key) {
        const next = Lib.toggle(habitNames, marks, i, key, today);
        marks = next;
        if (!preview) optionsEdited(Object.assign({}, options, { marks: next }));
    }

    // A day: a small square of glass, the tint lit inside when done; today's
    // has a firmer rim, and the pointer lifts it.
    component Day: Item {
        id: day
        property bool done: false
        property bool isToday: false
        property int habit: 0
        property string key: ""
        readonly property bool hovered: dayMouse.containsMouse
        Surface {
            anchors.fill: parent
            group: "widgets"
            level: 1
            radius: Tokens.radiusMark
            border.color: day.isToday ? Colors.alpha(Colors.text, day.hovered ? 0.55 : 0.38)
                        : day.hovered ? Colors.alpha(Colors.text, 0.3) : Materials.border("widgets")
        }
        // A done day is data, like a meter's fill: the accent itself, so it
        // reads on a light plate too, where frosted white alone would not.
        Rectangle {
            anchors.fill: parent
            radius: Tokens.radiusMark
            color: Colors.alpha(Colors.accent, Colors.dark ? 0.5 : 0.62)
            opacity: day.done ? 1 : 0
            Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.standard } }
        }
        ShellTint {
            anchors.fill: parent
            radius: Tokens.radiusMark
            group: "widgets"
            active: day.done
            hovered: day.hovered
        }
        MouseArea {
            id: dayMouse
            anchors.fill: parent
            anchors.margins: -2
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggle(day.habit, day.key)
        }
    }

    // The streak: a flame and the days in a row (dim at none).
    component Streak: Row {
        property int days: 0
        spacing: 2
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "streak"
            size: Tokens.textSize
            color: parent.days > 0 ? Colors.accent2 : Colors.textDim
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: String(parent.days)
            numeric: true
            role: parent.days > 0 ? "text" : "dim"
            size: Tokens.textSmall + 1
        }
    }

    WidgetHeader {
        id: head
        visible: root.sizeClass !== "S"
        height: visible ? implicitHeight : 0
        icon: "habit"; title: "Habits"
        trailing: root.rows.length ? root.doneToday + " of " + root.rows.length + " today" : ""
    }
    WidgetEmpty {
        visible: root.rows.length === 0
        icon: "habit"
        text: "Add habits in the editor"
    }

    // ---- S: today.
    Column {
        visible: root.sizeClass === "S" && root.rows.length > 0
        anchors.centerIn: parent
        width: root.width
        spacing: Tokens.gap * 0.5
        Metric {
            anchors.horizontalCenter: parent.horizontalCenter
            value: root.doneToday + "/" + root.rows.length
            unit: "today"
            size: Math.round(root.height * 0.24)
        }
        Repeater {
            model: root.rows.slice(0, 3)
            delegate: Row {
                id: srow
                required property var modelData
                anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                width: Math.min(root.width, implicitWidth)
                spacing: Tokens.gap * 0.5
                Day {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(Tokens.textSize * 1.1); height: width
                    done: srow.modelData.week[6].done
                    isToday: true
                    habit: srow.modelData.i
                    key: srow.modelData.week[6].key
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, root.width - Tokens.textSize * 1.6)
                    text: srow.modelData.name
                    role: srow.modelData.week[6].done ? "text" : "dim"
                    size: Tokens.textSmall + 1
                }
            }
        }
    }

    // ---- M and L: a row per habit.
    Item {
        id: grid
        visible: root.sizeClass !== "S" && root.rows.length > 0
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; topMargin: Tokens.gap * 0.3 }
        readonly property bool big: root.sizeClass === "L" || root.sizeClass === "XL"
        readonly property real streakW: root.showStreak ? Tokens.textSize * 2.8 : 0
        readonly property real nameW: Math.min(width * 0.34, Tokens.textSize * 8)
        readonly property real gap: Math.max(3, Math.round(Tokens.gap * 0.35))
        readonly property real rowH: Math.round(Tokens.textSize * (big ? 2.3 : 2.0))
        readonly property real square: Math.max(10, Math.min(rowH * 0.78, (width - nameW - streakW - Tokens.gap - 6 * gap) / 7))
        readonly property real daysX: nameW + Tokens.gap

        // The weekdays' initials over the squares (L).
        Item {
            id: initials
            visible: grid.big
            width: parent.width
            height: visible ? Math.round(Tokens.textSmall * 1.8) : 0
            Repeater {
                model: root.rows.length ? root.rows[0].week : []
                delegate: Label {
                    required property var modelData
                    required property int index
                    x: grid.daysX + index * (grid.square + grid.gap)
                    width: grid.square
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDate(modelData.date, "ddd").charAt(0)
                    role: index === 6 ? "text" : "dim"
                    font.weight: index === 6 ? Font.Medium : Font.Normal
                    size: Tokens.textSmall
                }
            }
        }
        ListView {
            id: listView
            anchors { left: parent.left; right: parent.right; top: initials.bottom; bottom: parent.bottom }
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.rows
            delegate: Item {
                id: hrow
                required property var modelData
                width: listView.width
                height: grid.rowH
                Label {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: grid.nameW
                    text: hrow.modelData.name
                }
                Repeater {
                    model: hrow.modelData.week
                    delegate: Day {
                        required property var modelData
                        required property int index
                        x: grid.daysX + index * (grid.square + grid.gap)
                        anchors.verticalCenter: parent.verticalCenter
                        width: grid.square; height: width
                        done: modelData.done
                        isToday: index === 6
                        habit: hrow.modelData.i
                        key: modelData.key
                    }
                }
                Streak {
                    visible: root.showStreak
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    days: hrow.modelData.streak
                }
            }
        }
    }
}
