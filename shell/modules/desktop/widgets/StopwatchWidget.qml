import QtQuick
import qs.services
import qs.theme
import qs.components
import "../../../lib/stopwatch.js" as Lib

/*
 * A stopwatch: start, pause, lap and reset.
 *   S   the time big, the last lap under it, the lit start key and lap / reset
 *   M   the header; the time and the keys on the left, the laps on the right
 *   L   the header; the time big, the keys under it, the laps below (split, total)
 * The time is worked out from timestamps kept in the options (since, acc,
 * laps: lib/stopwatch.js), so it runs on while hidden, and through a restart;
 * the face is redrawn ten times a second only while it runs and shows.
 * options: tenths (show tenths of a second); since, acc, laps (hidden: the state).
 * In a gallery card a sample run stands still, and the keys do nothing.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "S"
    property bool preview: false
    signal optionsEdited(var options)

    // A local copy, so a press shows at once, before the saved options come back.
    property var st: Lib.reset()
    readonly property var sample: ({ since: 0, acc: 754300, laps: ["228400", "471900", "698200"] })
    function load() {
        const saved = { since: Number(options.since) || 0, acc: Number(options.acc) || 0, laps: (options.laps || []).slice() };
        st = preview ? sample : saved;
        now = Date.now();
    }
    onOptionsChanged: load()
    onPreviewChanged: load()
    Component.onCompleted: load()

    property real now: Date.now()
    readonly property bool running: !preview && Lib.running(st)
    readonly property real ms: Lib.elapsed(st, now)
    readonly property bool tenths: options.tenths !== false
    readonly property string time: Lib.format(ms, tenths)
    readonly property var lapList: Lib.laps(st)
    readonly property bool zero: ms <= 0 && lapList.length === 0

    // Ticks only to redraw: nothing counts here.
    Timer {
        interval: root.tenths ? 100 : 500
        repeat: true; triggeredOnStart: true
        running: root.running && root.visible && !GameMode.active
        onTriggered: root.now = Date.now()
    }

    function save(next) {
        st = next;
        now = Date.now();
        if (!preview) optionsEdited(Object.assign({}, options, { since: next.since, acc: next.acc, laps: next.laps }));
    }
    function toggle() {
        if (preview) return;
        const t = Date.now();
        save(Lib.running(st) ? Lib.pause(st, t) : Lib.start(st, t));
    }
    function second() {
        if (preview) return;
        if (Lib.running(st)) save(Lib.lap(st, Date.now()));
        else if (!zero) save(Lib.reset());
    }

    // The keys: the start key is lit glass; lap while running, reset after.
    component KeyRow: Row {
        id: keys
        property bool wide: false
        spacing: Tokens.gap * 0.6
        GlassButton {
            group: "widgets"
            height: Math.round(Tokens.islandHeight * 0.95)
            width: keys.wide ? Math.max(implicitWidth, height * 2.6) : height
            icon: root.running ? "pause" : "play"
            label: keys.wide ? (root.running ? "Pause" : root.zero ? "Start" : "Resume") : ""
            primary: true
            onClicked: root.toggle()
        }
        GlassButton {
            group: "widgets"
            height: Math.round(Tokens.islandHeight * 0.95)
            width: keys.wide ? Math.max(implicitWidth, height * 2.6) : height
            icon: root.running ? "lap" : "restart"
            label: keys.wide ? (root.running ? "Lap" : "Reset") : ""
            enabled: root.running || !root.zero
            onClicked: root.second()
        }
    }

    // One lap: its number, its split (the best lit, the worst dim), the total.
    component LapRow: Item {
        id: lapRow
        required property var modelData
        property bool totals: true
        width: ListView.view ? ListView.view.width : 0
        height: Math.round(Tokens.textSize * 1.9)
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: Tokens.hairline
            color: Colors.alpha(Colors.text, 0.08)
        }
        Label {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: "Lap " + lapRow.modelData.n
            role: "dim"; size: Tokens.textSmall
        }
        Label {
            anchors { right: lapRow.totals ? total.left : parent.right; rightMargin: lapRow.totals ? Tokens.gap : 0; verticalCenter: parent.verticalCenter }
            text: Lib.format(lapRow.modelData.split, root.tenths)
            numeric: true
            role: lapRow.modelData.best ? "accent" : lapRow.modelData.worst ? "dim" : "text"
            font.weight: lapRow.modelData.best ? Font.Medium : Font.Normal
        }
        Label {
            id: total
            visible: lapRow.totals
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: Lib.format(lapRow.modelData.total, root.tenths)
            numeric: true
            role: "dim"; size: Tokens.textSmall
        }
    }

    WidgetHeader {
        id: head
        visible: root.sizeClass !== "S"
        height: visible ? implicitHeight : 0
        icon: "stopwatch"; title: "Stopwatch"
        trailing: root.lapList.length ? root.lapList.length + (root.lapList.length === 1 ? " lap" : " laps")
                : root.running ? "Running" : root.zero ? "" : "Paused"
    }

    // ---- S: the time over the keys.
    Column {
        visible: root.sizeClass === "S"
        anchors.centerIn: parent
        width: root.width
        spacing: Tokens.gap * 0.5
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.time
            numeric: true
            font.weight: Font.Light
            size: Math.round(Math.min(root.height * 0.27, root.width / Math.max(3, root.time.length * 0.6)))
            color: root.running || root.zero ? Colors.text : Colors.textDim
            elide: Text.ElideNone
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.lapList.length ? "Lap " + root.lapList[0].n + "  " + Lib.format(root.lapList[0].split, root.tenths)
                : root.running ? "Running" : root.zero ? "Ready" : "Paused"
            numeric: true
            role: "dim"; size: Tokens.textSmall
        }
        KeyRow { anchors.horizontalCenter: parent.horizontalCenter }
    }

    // ---- M: the time and keys | the laps.
    Item {
        visible: root.sizeClass === "M"
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; topMargin: Tokens.gap * 0.3 }
        Column {
            id: leftM
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: parent.width * 0.52
            spacing: Tokens.gap * 0.5
            Label {
                text: root.time
                numeric: true
                font.weight: Font.Light
                size: Math.round(Math.min(parent.parent.height * 0.42, leftM.width / Math.max(3, root.time.length * 0.6)))
                color: root.running || root.zero ? Colors.text : Colors.textDim
                elide: Text.ElideNone
            }
            KeyRow {}
        }
        ListView {
            id: lapsM
            anchors { left: leftM.right; leftMargin: Tokens.gap; right: parent.right; top: parent.top; bottom: parent.bottom }
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.lapList
            delegate: LapRow { totals: false }
            Label {
                anchors.centerIn: parent
                visible: lapsM.count === 0
                width: parent.width; horizontalAlignment: Text.AlignHCenter
                text: "Laps show here"
                role: "dim"; size: Tokens.textSmall
                wrapMode: Text.WordWrap
            }
        }
    }

    // ---- L: the time, the keys, the laps.
    Item {
        visible: root.sizeClass === "L" || root.sizeClass === "XL"
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; topMargin: Tokens.gap * 0.6 }
        Label {
            id: timeL
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.time
            numeric: true
            font.weight: Font.Light
            size: Math.round(Math.min(parent.height * 0.24, parent.width / Math.max(3, root.time.length * 0.6)))
            color: root.running || root.zero ? Colors.text : Colors.textDim
            elide: Text.ElideNone
        }
        KeyRow {
            id: keysL
            wide: true
            anchors { horizontalCenter: parent.horizontalCenter; top: timeL.bottom; topMargin: Tokens.gap * 0.4 }
        }
        ListView {
            id: lapsL
            anchors { left: parent.left; right: parent.right; top: keysL.bottom; topMargin: Tokens.gap * 0.8; bottom: parent.bottom }
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.lapList
            delegate: LapRow {}
            Label {
                anchors.centerIn: parent
                visible: lapsL.count === 0
                text: root.running ? "Lap to split the time" : "Laps show here"
                role: "dim"; size: Tokens.textSmall
            }
        }
    }
}
