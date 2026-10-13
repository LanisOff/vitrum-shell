import QtQuick
import qs.services
import qs.theme
import qs.components
import "../../../lib/timers.js" as Lib

/*
 * The timers (Timers: the same ones the launcher starts and the bar shows).
 *   S   the next to end as a ring, the time remaining inside, pause and stop under it;
 *       with none running, a chip per quick timer (and Pomodoro)
 *   M   the header; the ring beside the timer's name, when it ends, and the
 *       buttons; with none running, the chips
 * options: presets (minutes, one chip each), pomodoro (a Pomodoro chip).
 * In a gallery card a sample ring stands in, and the chips start nothing.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "S"
    property bool preview: false
    signal optionsEdited(var options)

    readonly property var sampleTimer: ({ id: 0, label: "Focus", kind: "pomodoro", phase: "work", round: 2, seconds: 1500, left: 754, paused: false, end: 0 })
    readonly property var timer: preview ? sampleTimer : Timers.next
    readonly property real remaining: !timer ? 0 : preview ? timer.left : Timers.leftOf(timer)
    readonly property real fraction: timer && timer.seconds > 0 ? remaining / timer.seconds : 0
    readonly property string leftText: timer ? Lib.format(remaining) : ""
    readonly property int others: preview ? 0 : Math.max(0, Timers.list.length - 1)

    readonly property var presets: (options.presets || []).map(p => Number(String(p).replace(",", ".")))
                                                           .filter(n => isFinite(n) && n > 0 && n <= 24 * 60)
    readonly property var chips: presets.map(n => ({ text: n + " min", minutes: n }))
                                        .concat(options.pomodoro !== false ? [{ text: "Pomodoro", minutes: 0 }] : [])

    function startChip(c) {
        if (preview) return;
        if (c.minutes > 0) Timers.start(Math.round(c.minutes * 60));
        else Timers.startPomodoro();
    }
    function togglePause() { if (!preview && timer) Timers.togglePause(timer.id); }
    function stop() { if (!preview && timer) Timers.cancel(timer.id); }

    readonly property string detail: {
        if (!timer) return "";
        if (timer.paused) return "Paused";
        const ends = preview ? new Date(Date.now() + remaining * 1000) : new Date(timer.end);
        return "Ends at " + Qt.formatTime(ends, Settings.get("clock.h24", true) ? "HH:mm" : "h:mm AP");
    }
    readonly property string name: !timer ? "" : timer.kind === "pomodoro"
        ? (timer.phase === "work" ? "Focus, round " + (timer.round || 1) : timer.phase === "long" ? "Long break" : "Short break")
        : timer.label

    component TimerButton: Rectangle {
        id: btn
        property string icon: ""
        property bool primary: false
        signal clicked()
        width: Math.round(Tokens.islandHeight * 0.95); height: width; radius: width / 2
        color: primary ? Colors.alpha(Colors.accent, Colors.dark ? 0.32 : 0.22) : Colors.alpha(Colors.text, btnMouse.containsMouse ? 0.12 : 0.07)
        Behavior on color { enabled: Motion.enabled; ColorAnim {} }
        Icon { anchors.centerIn: parent; name: btn.icon; size: Math.round(btn.width * 0.55); filled: true; color: btn.primary ? Colors.accent : Colors.text }
        MouseArea { id: btnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked() }
    }
    component PresetChip: Rectangle {
        id: chip
        property string text: ""
        property bool primary: false
        signal clicked()
        width: chipLabel.implicitWidth + Tokens.gap * 1.6; height: Math.round(Tokens.islandHeight * 0.9)
        radius: Tokens.radiusInner
        color: primary ? Colors.alpha(Colors.accent, Colors.dark ? 0.32 : 0.22) : Colors.alpha(Colors.text, chipMouse.containsMouse ? 0.12 : 0.07)
        Behavior on color { enabled: Motion.enabled; ColorAnim {} }
        Label { id: chipLabel; anchors.centerIn: parent; text: chip.text; numeric: true; size: Tokens.textSmall + 1; font.weight: Font.Medium; role: chip.primary ? "accent" : "text" }
        MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
    }

    WidgetHeader {
        id: head
        visible: root.sizeClass !== "S"
        height: visible ? implicitHeight : 0
        icon: "timer"; title: "Timer"
        trailing: root.others > 0 ? "+" + root.others + " more" : ""
    }

    // The ring, the time remaining inside it; placed by the layouts below.
    component Dial: Meter {
        id: dial
        property string time: ""
        property string sub: ""
        property bool paused: false
        kind: "circular"
        color: paused ? Colors.textDim : Colors.accent
        Column {
            anchors.centerIn: parent
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dial.time
                numeric: true
                font.weight: Font.Light
                size: Math.max(Tokens.textSmall, Math.round(Math.min(dial.width * 0.26, dial.width * 0.62 / Math.max(3, dial.time.length * 0.6))))
            }
            Label {
                visible: dial.sub.length > 0 && dial.width > 96
                anchors.horizontalCenter: parent.horizontalCenter
                text: dial.sub
                role: "dim"; size: Tokens.textSmall
            }
        }
    }

    // ---- running, S: the ring over the buttons.
    Column {
        visible: !!root.timer && root.sizeClass === "S"
        anchors.centerIn: parent
        spacing: Tokens.gap * 0.5
        Dial {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(48, Math.min(root.width, root.height - buttonsS.height - parent.spacing)); height: width
            value: root.fraction
            time: root.leftText
            paused: !!root.timer && root.timer.paused
        }
        Row {
            id: buttonsS
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Tokens.gap * 0.6
            TimerButton { icon: root.timer && root.timer.paused ? "play" : "pause"; primary: true; onClicked: root.togglePause() }
            TimerButton { icon: "stop"; onClicked: root.stop() }
        }
    }

    // ---- running, M: the ring beside what it is.
    Row {
        visible: !!root.timer && root.sizeClass !== "S"
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: Tokens.gap * 0.5; bottom: parent.bottom }
        spacing: Tokens.gap * 1.2
        Dial {
            id: dialM
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(48, Math.min(parent.height, 132)); height: width
            value: root.fraction
            time: root.leftText
            paused: !!root.timer && root.timer.paused
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - dialM.width - parent.spacing
            spacing: Tokens.gap * 0.5
            Column {
                width: parent.width
                Label { width: parent.width; text: root.name; font.weight: Font.Medium }
                Label { width: parent.width; text: root.detail; role: "dim"; size: Tokens.textSmall }
            }
            Row {
                spacing: Tokens.gap * 0.6
                TimerButton { icon: root.timer && root.timer.paused ? "play" : "pause"; primary: true; onClicked: root.togglePause() }
                TimerButton { icon: "stop"; onClicked: root.stop() }
            }
        }
    }

    // ---- none running: the quick timers.
    Column {
        visible: !root.timer
        anchors { left: parent.left; right: parent.right; verticalCenter: root.sizeClass === "S" ? parent.verticalCenter : undefined
                  top: root.sizeClass === "S" ? undefined : head.bottom; topMargin: Tokens.gap * 0.6 }
        spacing: Tokens.gap * 0.6
        Icon {
            visible: root.sizeClass === "S"
            anchors.horizontalCenter: parent.horizontalCenter
            name: "timer"
            size: Math.round(root.height * 0.22)
            color: Colors.accent
        }
        Label {
            visible: root.sizeClass !== "S"
            text: root.chips.length ? "Start a timer" : "Add quick timers in the editor"
            role: "dim"; size: Tokens.textSmall
        }
        Label {
            visible: root.sizeClass === "S" && root.chips.length === 0
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: "Add quick timers in the editor"
            wrapMode: Text.WordWrap
            role: "dim"; size: Tokens.textSmall
        }
        Flow {
            id: flow
            // Centred at S: as wide as its chips are, at most the widget.
            width: root.sizeClass === "S" ? Math.min(parent.width, chipsWidth) : parent.width
            anchors.horizontalCenter: root.sizeClass === "S" ? parent.horizontalCenter : undefined
            spacing: 6
            readonly property real chipsWidth: { let w = 0; for (let i = 0; i < children.length; i++) w += children[i].width + spacing; return w; }
            Repeater {
                model: root.chips
                delegate: PresetChip {
                    required property var modelData
                    text: modelData.text
                    primary: modelData.minutes === 0
                    onClicked: root.startChip(modelData)
                }
            }
        }
    }
}
