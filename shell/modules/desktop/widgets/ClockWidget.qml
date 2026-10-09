import QtQuick
import QtQuick.Effects
import qs.services
import qs.theme
import qs.components
import "../../lock"

// The time cut out of glass, like the lock screen's: no plate, the wallpaper
// bends through the digits (Desktop's backdrop). The date under it.
// Without a backdrop, or with solid widgets, the same clock painted.
Item {
    id: root
    property var options: ({})
    property bool toned: false
    property Item backdrop: null
    property Item source: null
    property date now: new Date()
    // The tick also re-places the glass over the backdrop: the desktop draws no
    // frames of its own to do it on, and the widget may have been moved.
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { root.now = new Date(); glass._sync(); } }

    readonly property string time: Qt.formatTime(now, Settings.get("clock.h24", true) ? "HH:mm" : "h:mm")
    // Bold digits run about 0.62 of the size each; the date takes a fifth below.
    readonly property real timeSize: Math.max(32, Math.min(height * 0.7, width / (time.length * 0.6)))
    readonly property bool glass: !!backdrop && Materials.of("widgets") !== "solid"

    Column {
        anchors.centerIn: parent
        spacing: 0

        Glass {
            id: glass
            anchors.horizontalCenter: parent.horizontalCenter
            width: clock.width; height: clock.height
            visible: root.glass
            backdrop: root.backdrop
            source: root.source
            // Stronger than the lock's: there the picture around is blurred and
            // the clear digits stand out by themselves; here it is as sharp as
            // they are, so the rims carry the glass.
            bevel: clock.size * 0.14
            refraction: clock.size * 0.5
            edgeLight: 1.8
            fringing: 0.5
            saturation: 1.4
            brightness: 0.07
            tint: Qt.rgba(1, 1, 1, Colors.dark ? 0.05 : 0.12)
            shadow: 0.6
            LockClock {
                id: clock
                time: root.time
                size: root.timeSize
                weight: Font.Bold
                color: "white"
            }
        }
        LockClock {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.glass
            height: visible ? implicitHeight : 0
            time: root.time; size: root.timeSize; weight: Font.Bold
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.now, "dddd, d MMMM")
            size: Math.max(Tokens.textSmall, root.timeSize * 0.17)
            font.weight: Font.DemiBold
            color: "white"
            // On the bare wallpaper: a soft shadow keeps it readable on light pictures.
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.6; shadowColor: Qt.rgba(0, 0, 0, 0.55); shadowVerticalOffset: 1 }
        }
    }
}
