import QtQuick
import qs.services
import qs.theme
import qs.components

// Your own bind: a name, a command, then the key combination.
Column {
    id: ob
    property var list: []
    property int index: -1
    property var entry: ({ keys: "", command: "", title: "" })
    signal done(var entry)
    signal cancelled()
    spacing: Tokens.gap
    width: parent ? parent.width : 0
    component Field: Rectangle {
        id: field
        property alias text: input.text
        property string placeholder: ""
        width: ob.width; height: Tokens.islandHeight * 1.1; radius: Tokens.radiusInner
        color: Colors.alpha(Colors.text, 0.06)
        border.width: input.activeFocus ? 2 : 0
        border.color: Colors.accent
        TextInput {
            id: input
            anchors { fill: parent; leftMargin: Tokens.gap; rightMargin: Tokens.gap }
            verticalAlignment: TextInput.AlignVCenter
            font.family: Tokens.fontText; font.pixelSize: Tokens.textSize; color: Colors.text; clip: true
            Label { visible: !input.text; text: field.placeholder; role: "dim"; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    Field { id: title; text: ob.entry.title || ""; placeholder: "Name (shown in the shortcut sheet)" }
    Field { id: cmd; text: ob.entry.command || ""; placeholder: "Command, e.g. firefox or kitty --directory ~" }
    Label { visible: !cmd.text.trim(); text: "Enter a command"; role: "dim"; size: Tokens.textSmall }
    KeyEditor {
        list: ob.list; startKeys: ob.entry.keys || ""; selfOwn: ob.index
        onSaved: keys => { if (cmd.text.trim()) ob.done({ keys: keys, command: cmd.text.trim(), title: title.text.trim() || cmd.text.trim() }); }
        onCancelled: ob.cancelled()
    }
}
