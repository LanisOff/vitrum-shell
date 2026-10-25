import QtQuick
import QtQuick.Shapes
import qs.services
import qs.theme
import qs.components
import "../../../lib/moon.js" as Lib

/*
 * The moon tonight: its phase drawn, its name, how much of it is lit, and when
 * the next full and new moons are (lib/moon.js: worked out, nothing fetched).
 *   S   the moon, the phase's name and the lit share under it
 *   M   the header (the lit share); the moon beside the name and the dates of
 *       the next full and new moon
 * The disc is the dark glass of the unlit moon with the lit part laid on it:
 * the limb's half circle closed by the terminator's half ellipse. Seen from
 * the south it is mirrored (hemisphere: auto follows the weather's place).
 * options: next (the next full and new moon), hemisphere (auto, north, south).
 * In a gallery card a waxing gibbous moon of a fixed day stands in.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "S"
    property bool preview: false
    signal optionsEdited(var options)

    property date now: new Date()
    // The phase moves slowly: every ten minutes is plenty.
    Timer {
        interval: 10 * 60 * 1000; repeat: true; triggeredOnStart: true
        running: !root.preview && root.visible && !GameMode.active
        onTriggered: root.now = new Date()
    }
    readonly property date at: preview ? new Date(2026, 9, 20, 12, 0) : now

    readonly property bool south: options.hemisphere === "south" || (options.hemisphere !== "north" && Sun.lat < 0)
    readonly property var info: Lib.info(at)
    readonly property var drawn: Lib.shape(info.elongation, south)
    readonly property date nextFull: Lib.nextFull(at)
    readonly property date nextNew: Lib.nextNew(at)
    // Rounded, but never "100%" short of the full moon nor "0%" off the new one.
    readonly property int pct: {
        const p = Math.round(info.illumination * 100);
        return p === 100 && info.phase !== "full" ? 99 : p === 0 && info.phase !== "new" ? 1 : p;
    }
    readonly property string lit: pct + "% lit"
    readonly property bool h24: Settings.get("clock.h24", true)

    function when(d) {
        const days = Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - new Date(at.getFullYear(), at.getMonth(), at.getDate())) / 86400000);
        const day = days === 0 ? "Today" : days === 1 ? "Tomorrow" : Qt.formatDate(d, "ddd d MMM");
        return day + ", " + Qt.formatTime(d, h24 ? "HH:mm" : "h:mm AP");
    }

    // The moon: a disc of dark glass, the lit part on it.
    component Disc: Item {
        id: disc
        readonly property real r: width / 2
        // The terminator's half-width, kept off zero so the arc stays an arc.
        readonly property real rx: Math.max(0.01, Math.abs(root.drawn.bulge) * r)
        // The terminator runs through the limb's side when it is a crescent.
        readonly property bool viaLitSide: root.drawn.bulge > 0
        readonly property bool rightLit: root.drawn.side > 0
        readonly property color light: Colors.dark ? Qt.hsla(0.12, 0.30, 0.86, 1) : Qt.hsla(0.11, 0.42, 0.97, 1)
        height: width
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Colors.dark ? Colors.alpha(Colors.text, 0.07) : Colors.alpha(Colors.text, 0.10)
            border.width: Tokens.hairline
            border.color: Colors.alpha(Colors.text, 0.20)
        }
        Shape {
            anchors.fill: parent
            visible: root.info.illumination > 0.003
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"; strokeWidth: 0
                fillGradient: LinearGradient {
                    // A faint fall-off toward the terminator, the light from the lit side.
                    x1: disc.rightLit ? disc.width : 0; y1: 0
                    x2: disc.rightLit ? 0 : disc.width; y2: disc.height
                    GradientStop { position: 0; color: disc.light }
                    GradientStop { position: 1; color: Qt.darker(disc.light, Colors.dark ? 1.12 : 1.06) }
                }
                startX: disc.r; startY: 0
                // The limb: top → the lit side → bottom.
                PathArc {
                    x: disc.r; y: disc.width
                    radiusX: disc.r; radiusY: disc.r
                    direction: disc.rightLit ? PathArc.Clockwise : PathArc.Counterclockwise
                }
                // The terminator back up: through the lit side for a crescent.
                PathArc {
                    x: disc.r; y: 0
                    radiusX: disc.rx; radiusY: disc.r
                    direction: disc.rightLit === disc.viaLitSide ? PathArc.Counterclockwise : PathArc.Clockwise
                }
            }
        }
        // The rim of the glass over it.
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: Tokens.hairline
            border.color: Colors.alpha(Colors.text, 0.12)
        }
    }

    WidgetHeader {
        id: head
        visible: root.sizeClass !== "S"
        height: visible ? implicitHeight : 0
        icon: "moon"; title: "Moon"
        trailing: root.lit
    }

    // ---- S: the moon over its name.
    Column {
        visible: root.sizeClass === "S"
        anchors.centerIn: parent
        width: root.width
        spacing: Tokens.gap * 0.5
        Disc {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(Math.min(root.width * 0.62, root.height - nameS.height * 2 - parent.spacing * 2))
        }
        Label {
            id: nameS
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: root.info.name
            font.weight: Font.Medium
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.lit
            numeric: true
            role: "dim"; size: Tokens.textSmall
        }
    }

    // ---- M: the moon beside its name and the dates.
    Item {
        visible: root.sizeClass !== "S"
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; topMargin: Tokens.gap * 0.4 }
        Disc {
            id: discM
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(Math.min(parent.height, parent.width * 0.4))
        }
        Column {
            anchors { left: discM.right; leftMargin: Tokens.gap * 1.2; right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: Tokens.gap * 0.5
            Label {
                width: parent.width
                text: root.info.name
                size: Tokens.textLarge
                font.weight: Font.Medium
            }
            Column {
                visible: root.options.next !== false
                width: parent.width
                spacing: 2
                Repeater {
                    model: root.info.phase === "full" || root.nextNew < root.nextFull
                        ? [{ t: "New moon", d: root.nextNew }, { t: "Full moon", d: root.nextFull }]
                        : [{ t: "Full moon", d: root.nextFull }, { t: "New moon", d: root.nextNew }]
                    delegate: Column {
                        required property var modelData
                        width: parent.width
                        Label { width: parent.width; text: modelData.t; role: "dim"; size: Tokens.textSmall }
                        Label { width: parent.width; text: root.when(modelData.d); numeric: true; size: Tokens.textSmall + 1 }
                    }
                }
            }
        }
    }
}
