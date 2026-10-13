import QtQuick
import qs.services
import qs.theme
import qs.components

/*
 * The graphics card's load and temperature (SysInfo: NVIDIA, through nvidia-smi).
 *   S   the load as a ring, the temperature under it
 *   M   the header (the temperature at its end); the load; the last two
 *       minutes of it as a graph beside it
 *   L   as M, the graph under the load, and the temperature as a bar
 * options: graph (the load graph; without it, the load as a bar).
 * In a gallery card with no GPU figures, a sample card stands in.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    Component.onCompleted: SysInfo.subscribe()
    Component.onDestruction: SysInfo.unsubscribe()

    readonly property bool sample: preview && !SysInfo.gpuAvailable
    readonly property bool ready: SysInfo.gpuAvailable || sample
    readonly property real load: sample ? 0.46 : SysInfo.gpuUsage
    readonly property real temp: sample ? 62 : SysInfo.gpuTemp
    readonly property bool graph: options.graph !== false
    readonly property bool wide: sizeClass === "M"
    readonly property bool tall: sizeClass === "L" || sizeClass === "XL"
    readonly property color heat: temp > 75 ? Colors.meaning(0.07) : Colors.accent

    // Sixty samples, two seconds apart (nvidia-smi's own pace).
    readonly property int points: 60
    property var history: []
    readonly property var sampleSeries: Array.from({ length: 60 }, (_, i) => 0.42 + 0.18 * Math.sin(i / 6) + 0.07 * Math.sin(i * 1.3))
    readonly property var series: sample ? sampleSeries : history
    Timer {
        interval: 2000; repeat: true; running: SysInfo.gpuAvailable
        onTriggered: {
            const l = root.history.concat([SysInfo.gpuUsage]);
            root.history = l.length > root.points ? l.slice(l.length - root.points) : l;
        }
    }

    WidgetHeader {
        id: head
        visible: root.sizeClass !== "S"
        height: visible ? implicitHeight : 0
        icon: "gpu"; title: "GPU"
        trailing: root.ready && root.temp > 0 ? Math.round(root.temp) + " °C" : ""
    }
    WidgetEmpty {
        visible: !root.ready
        icon: "gpu"
        text: "No GPU data (NVIDIA only)"
    }

    // ---- S: one glance.
    Column {
        visible: root.ready && root.sizeClass === "S"
        anchors.centerIn: parent
        spacing: Tokens.gap * 0.6
        Meter {
            anchors.horizontalCenter: parent.horizontalCenter
            kind: "circular"
            width: Math.min(root.width, root.height) * 0.68; height: width
            value: root.load
            trailing: Math.round(root.load * 100) + "%"
            color: Colors.accent
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.temp > 0 ? Math.round(root.temp) + " °C" : "GPU"
            role: "dim"; size: Tokens.textSmall; numeric: true
        }
    }

    // ---- M and L: the load.
    Metric {
        id: big
        visible: root.ready && root.sizeClass !== "S"
        anchors { left: parent.left; top: head.bottom; topMargin: Tokens.gap * 0.6 }
        value: String(Math.round(root.load * 100))
        unit: "%"
        label: "Load"
        size: root.wide ? Math.max(26, Math.min(48, (root.height - head.height) * 0.45))
                        : Math.max(32, Math.min(64, root.height * 0.18))
    }
    // M: beside the number; L: under it, down to the temperature.
    Sparkline {
        visible: root.ready && root.sizeClass !== "S" && root.graph
        anchors {
            left: root.wide ? big.right : parent.left
            leftMargin: root.wide ? Tokens.gap * 1.5 : 0
            right: parent.right
            top: root.wide ? head.bottom : big.bottom
            topMargin: Tokens.gap
            bottom: root.tall ? tempBar.top : parent.bottom
            bottomMargin: root.tall ? Tokens.gap * 1.5 : 0
        }
        values: root.series
        max: 1
        color: Colors.accent
    }
    // No graph: the load as a bar, along the bottom (L: above the temperature).
    Meter {
        visible: root.ready && root.sizeClass !== "S" && !root.graph
        anchors {
            left: parent.left; right: parent.right
            bottom: root.tall ? tempBar.top : parent.bottom
            bottomMargin: root.tall ? Tokens.gap * 1.5 : 0
        }
        value: root.load
        color: Colors.accent
    }
    // ---- L: the temperature, orange once it runs hot.
    Meter {
        id: tempBar
        visible: root.ready && root.tall
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        label: "Temperature"
        trailing: root.temp > 0 ? Math.round(root.temp) + " °C" : "—"
        value: root.temp / 100
        color: root.heat
    }
}
