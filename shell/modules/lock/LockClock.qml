import QtQuick
import qs.theme
import qs.components

// The big clock. Each character rolls when it changes: the old one slides up
// and fades while the new one comes in from below.
Row {
    id: clock
    property string time: ""
    property real size: Tokens.textTitle * 4
    property int weight: Font.Light
    property color color: Colors.text

    Repeater {
        // A count, not the characters: delegates stay put while digits change.
        model: clock.time.length
        delegate: Item {
            id: cell
            required property int index
            readonly property string ch: clock.time.charAt(index)
            property string shown: ch
            property string old: ""
            property real t: 1
            width: Math.max(now.implicitWidth, gone.implicitWidth)
            height: now.implicitHeight
            clip: true
            onChChanged: {
                if (!Motion.enabled) { shown = ch; return; }
                old = shown; shown = ch;
                roll.restart();
            }
            NumberAnimation { id: roll; target: cell; property: "t"; from: 0; to: 1; duration: Motion.emphasized * 1.4; easing.type: Easing.OutCubic }
            Label {
                id: gone
                text: cell.old
                numeric: true
                size: clock.size
                font.weight: clock.weight
                color: clock.color
                opacity: 1 - cell.t
                y: -cell.t * cell.height * 0.6
                visible: cell.t < 1
            }
            Label {
                id: now
                text: cell.shown
                numeric: true
                size: clock.size
                font.weight: clock.weight
                color: clock.color
                opacity: cell.t
                y: (1 - cell.t) * cell.height * 0.6
            }
        }
    }
}
