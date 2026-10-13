import QtQuick
import qs.services
import qs.theme
import qs.components

/*
 * A sticky note, typed straight into the widget.
 *   S   the text alone, edge to edge
 *   M   the header, the text under it
 *   L   as M, with room to scroll
 * options: fontSize, text (hidden: the note itself, saved a moment after typing stops).
 * In a gallery card: a sample note, read only.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    readonly property string stored: options.text || ""
    readonly property int fontSize: Math.max(11, Math.min(28, Number(options.fontSize) || 14))

    // Changed elsewhere (another screen, the file): take it, unless this note is being edited.
    onStoredChanged: if (!root.preview && !edit.activeFocus && edit.text !== stored) edit.text = stored
    onPreviewChanged: edit.text = preview && !stored ? "Buy milk\nCall mum" : stored

    WidgetHeader {
        id: head
        visible: root.sizeClass !== "S"
        height: visible ? implicitHeight : 0
        icon: "edit"; title: "Notes"
    }
    Flickable {
        id: flick
        anchors { fill: parent; topMargin: head.visible ? head.height + Tokens.gap * 0.6 : 0 }
        contentWidth: width
        contentHeight: edit.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        // Keeps the caret in view while typing past the bottom.
        function follow(r) {
            if (r.y < contentY) contentY = r.y;
            else if (r.y + r.height > contentY + height) contentY = r.y + r.height - height;
        }
        TextEdit {
            id: edit
            width: flick.width
            wrapMode: TextEdit.Wrap
            readOnly: root.preview
            selectByMouse: true
            font.family: Tokens.fontText
            font.pixelSize: root.fontSize
            color: Colors.text
            selectionColor: Colors.alpha(Colors.accent, 0.45)
            selectedTextColor: Colors.text
            // Not bound: a saved copy coming back must not overwrite what is being typed.
            Component.onCompleted: text = root.preview && !root.stored ? "Buy milk\nCall mum" : root.stored
            onTextChanged: if (!root.preview && text !== root.stored) save.restart()
            onCursorRectangleChanged: if (activeFocus) flick.follow(cursorRectangle)
            Label {
                visible: edit.text.length === 0 && !edit.activeFocus
                text: "Write something…"
                role: "dim"
                size: root.fontSize
            }
        }
        // A click under the last line still lands in the note.
        MouseArea {
            y: edit.implicitHeight
            width: flick.width; height: Math.max(0, flick.height - edit.implicitHeight)
            enabled: !root.preview
            cursorShape: Qt.IBeamCursor
            onClicked: { edit.forceActiveFocus(); edit.cursorPosition = edit.length; }
        }
    }
    Timer { id: save; interval: 600; onTriggered: root.commit() }
    function commit() {
        if (root.preview || edit.text === root.stored) return;
        const o = Object.assign({}, root.options);
        o.text = edit.text;
        root.optionsEdited(o);
    }
    // Typed just before the widget went away (the editor opened, a relayout): keep it.
    Component.onDestruction: if (save.running) commit()
}
