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

    // Typing must never go into a field you cannot see. A text field (a
    // TextInput or TextEdit) loses the keyboard on a press anywhere outside it
    // — empty page or another control — and once the page scrolls it fully out
    // of view; SettingText saves when it loses it. The page takes the keyboard
    // then (Escape still reaches the window).
    function _typing() {
        const f = page.Window.activeFocusItem;
        return f && f.cursorRectangle !== undefined ? f : null;
    }
    function _inside(f) { let a = f; while (a && a !== page) a = a.parent; return a === page; }
    function _release(pressAt) {
        const f = _typing();
        if (!f) return;
        if (pressAt) {
            const p = f.mapFromItem(catcher, pressAt.x, pressAt.y);
            if (p.x >= 0 && p.y >= 0 && p.x <= f.width && p.y <= f.height) return;
        } else {
            if (!_inside(f)) return;
            const y = f.mapToItem(page, 0, 0).y;
            if (y + f.height > 0 && y < page.height) return;
        }
        page.forceActiveFocus();
    }
    onContentYChanged: _release(null)

    // Over the whole content: sees every press first and hands it on (not
    // accepted, so the control under it gets the press and a drag still
    // scrolls; no hover, no wheel, no cursor of its own).
    MouseArea {
        id: catcher
        z: 1000
        width: page.width
        height: Math.max(page.height, page.contentHeight)
        acceptedButtons: Qt.AllButtons
        onPressed: m => { page._release(Qt.point(m.x, m.y)); m.accepted = false; }
    }

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
        NumberAnimation { target: slide; property: "x"; to: 0; duration: Motion.emphasized; easing.type: Easing.OutQuint }
        NumberAnimation { target: head; property: "opacity"; to: 1; duration: Motion.standard; easing.type: Easing.OutCubic }
    }
}
