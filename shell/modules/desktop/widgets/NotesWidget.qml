import QtQuick
import qs.theme
import qs.components

// A sticky note; the text is kept in the widget's options (saved a moment after typing stops).
Item {
    id: root
    property var options: ({})
    signal optionsEdited(var options)
    // Changed elsewhere (another screen, the file): take it, unless this note is being edited.
    onOptionsChanged: if (!edit.activeFocus && edit.text !== (options.text || "")) edit.text = options.text || ""
    WidgetHeader { id: head; icon: "edit"; title: "Notes"; hue: 40 }
    Flickable {
        anchors { fill: parent; topMargin: head.height + 6 }
        contentHeight: edit.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        TextEdit {
            id: edit
            width: parent.width
            wrapMode: TextEdit.Wrap
            font.family: Tokens.fontText
            font.pixelSize: Tokens.textSize + 1
            color: Colors.text
            selectionColor: Colors.accent
            // Not bound: a saved copy coming back must not overwrite what is being typed.
            Component.onCompleted: text = root.options.text || ""
            onTextChanged: if (text !== (root.options.text || "")) save.restart()
            Label { visible: edit.text.length === 0 && !edit.activeFocus; text: "Write something…"; role: "dim" }
        }
    }
    Timer { id: save; interval: 800; onTriggered: root.optionsEdited(Object.assign({}, root.options, { text: edit.text })) }
}
