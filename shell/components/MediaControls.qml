import QtQuick
import QtQuick.Shapes
import qs.services
import qs.theme

// Previous, play/pause, next — solid shapes in round buttons (play/pause on
// the accent), the same in the bar, the player card and on the lock screen.
// Drawn, not font glyphs: the icon font's fill axis is not honoured
// everywhere, and outlined media symbols read as text.
//   size: a button's diameter; small: the bar's (no ring until hovered)
Row {
    id: root
    property real size: Tokens.islandHeight
    property bool small: false
    spacing: small ? 2 : Tokens.gap * 0.6

    component Btn: Item {
        id: b
        property string icon: ""
        property bool main: false
        signal clicked()
        width: root.size * (main && !root.small ? 1.15 : 1); height: width
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: b.main ? Colors.accent
                 : m.pressed ? Colors.alpha(Colors.text, 0.18)
                 : m.containsMouse ? Colors.alpha(Colors.text, 0.12)
                 : root.small ? "transparent" : Colors.alpha(Colors.text, 0.06)
            Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
        }
        Glyph {
            anchors.centerIn: parent
            kind: b.icon
            width: Math.round(b.width * (b.main ? 0.42 : 0.4)); height: width
            color: b.main ? Colors.onAccent : Colors.text
        }
        scale: m.pressed ? 0.86 : m.containsMouse ? 1.06 : 1
        Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
        MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    }

    // A media symbol in a unit square: play ▸, pause ‖, previous |◂, next ▸|.
    component Glyph: Shape {
        id: g
        property string kind: "play"
        property color color: Colors.text
        preferredRendererType: Shape.CurveRenderer
        readonly property real u: width
        // play: a triangle a little right of centre, as optical balance wants
        ShapePath {
            fillColor: g.kind === "play" ? g.color : "transparent"; strokeWidth: -1
            startX: g.u * 0.2; startY: g.u * 0.08
            PathLine { x: g.u * 0.95; y: g.u * 0.5 }
            PathLine { x: g.u * 0.2; y: g.u * 0.92 }
            PathLine { x: g.u * 0.2; y: g.u * 0.08 }
        }
        // pause: two rounded bars
        ShapePath {
            fillColor: g.kind === "pause" ? g.color : "transparent"; strokeWidth: -1
            PathRectangle { x: g.u * 0.14; y: g.u * 0.06; width: g.u * 0.26; height: g.u * 0.88; radius: g.u * 0.07 }
            PathRectangle { x: g.u * 0.6; y: g.u * 0.06; width: g.u * 0.26; height: g.u * 0.88; radius: g.u * 0.07 }
        }
        // previous: a bar and a triangle pointing left
        ShapePath {
            fillColor: g.kind === "previous" ? g.color : "transparent"; strokeWidth: -1
            PathRectangle { x: g.u * 0.06; y: g.u * 0.1; width: g.u * 0.16; height: g.u * 0.8; radius: g.u * 0.05 }
            PathMove { x: g.u * 0.94; y: g.u * 0.1 }
            PathLine { x: g.u * 0.26; y: g.u * 0.5 }
            PathLine { x: g.u * 0.94; y: g.u * 0.9 }
            PathLine { x: g.u * 0.94; y: g.u * 0.1 }
        }
        // next: the same, the other way
        ShapePath {
            fillColor: g.kind === "next" ? g.color : "transparent"; strokeWidth: -1
            PathRectangle { x: g.u * 0.78; y: g.u * 0.1; width: g.u * 0.16; height: g.u * 0.8; radius: g.u * 0.05 }
            PathMove { x: g.u * 0.06; y: g.u * 0.1 }
            PathLine { x: g.u * 0.74; y: g.u * 0.5 }
            PathLine { x: g.u * 0.06; y: g.u * 0.9 }
            PathLine { x: g.u * 0.06; y: g.u * 0.1 }
        }
    }

    Btn { icon: "previous"; onClicked: Media.previous() }
    Btn { icon: Media.playing ? "pause" : "play"; main: true; onClicked: Media.playPause() }
    Btn { icon: "next"; onClicked: Media.next() }
}
