import QtQuick
import qs.theme
import qs.components

// A scrolling page of sections, with a title and an optional subtitle.
// enter() — on creation, and whenever the page shows something else — slides
// the title in and brings the sections up one after another.
Flickable {
    id: page
    property string title: ""
    property string subtitle: ""
    default property alias content: col.data
    contentHeight: col.implicitHeight + Tokens.padding * 3
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    function enter() {
        if (!Motion.enabled) return;
        contentY = 0;
        head.opacity = 0;
        slide.x = 28;
        headIn.restart();
        let n = 0;
        for (let i = 0; i < col.children.length; i++) {
            const c = col.children[i];
            if (c !== head && c.visible && typeof c.enter === "function") c.enter(n++);
        }
    }
    Component.onCompleted: enter()

    Column {
        id: col
        x: Tokens.padding * 2
        y: Tokens.padding
        width: page.width - Tokens.padding * 4
        spacing: Tokens.gap * 2
        Column {
            id: head
            width: parent.width
            spacing: 2
            transform: Translate { id: slide }
            Label { text: page.title; size: Tokens.textTitle; font.weight: Font.DemiBold }
            Label { visible: text.length > 0; width: parent.width; text: page.subtitle; role: "dim"; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        }
    }
    ParallelAnimation {
        id: headIn
        NumberAnimation { target: slide; property: "x"; to: 0; duration: Motion.emphasized; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
        NumberAnimation { target: head; property: "opacity"; to: 1; duration: Motion.standard; easing.type: Easing.OutCubic }
    }
}
