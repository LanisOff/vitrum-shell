import QtQuick
import qs.theme
import qs.components

// A titled card of rows. Page.enter() brings it up into place, a little after
// the sections above it.
Column {
    id: sec
    property string title: ""
    property string note: ""
    default property alias content: card.data
    width: parent ? parent.width : 400
    spacing: Tokens.gap / 2
    transform: Translate { id: rise }

    function enter(order) {
        enterAnim.stop();
        opacity = 0;
        rise.y = 22;
        enterAnim.delay = Math.min(order, 8) * 45;
        enterAnim.start();
    }
    SequentialAnimation {
        id: enterAnim
        property int delay: 0
        PauseAnimation { duration: enterAnim.delay }
        ParallelAnimation {
            NumberAnimation { target: rise; property: "y"; to: 0; duration: Motion.emphasized; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
            NumberAnimation { target: sec; property: "opacity"; to: 1; duration: Motion.standard; easing.type: Easing.OutCubic }
        }
    }

    Label { visible: sec.title.length > 0; text: sec.title; role: "dim"; size: Tokens.textSmall; font.weight: Font.DemiBold; leftPadding: Tokens.padding * 0.5 }
    Surface {
        id: cardSurface
        width: sec.width
        height: card.implicitHeight
        group: "panels"; level: 1; outlined: false
        radius: Tokens.radiusInner
        Column {
            id: card
            width: parent.width
        }
    }
    Label { visible: sec.note.length > 0; width: sec.width; text: sec.note; role: "dim"; size: Tokens.textSmall; wrapMode: Text.WordWrap; elide: Text.ElideNone; leftPadding: Tokens.padding * 0.5 }
}
