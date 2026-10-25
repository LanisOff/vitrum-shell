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
    Field { id: title; width: ob.width; text: ob.entry.title || ""; placeholder: "Name (shown in the shortcut sheet)" }
    Field { id: cmd; width: ob.width; text: ob.entry.command || ""; placeholder: "Command, e.g. firefox or kitty --directory ~" }
    // Keeps its place once a command is typed, so the keys below do not jump.
    Label { opacity: cmd.text.trim() ? 0 : 1; text: "Enter a command"; role: "dim"; size: Tokens.textSmall }
    // The name first: the key catcher takes the focus as it opens.
    Component.onCompleted: Qt.callLater(title.takeFocus)
    KeyEditor {
        list: ob.list; startKeys: ob.entry.keys || ""; selfOwn: ob.index
        onSaved: keys => { if (cmd.text.trim()) ob.done({ keys: keys, command: cmd.text.trim(), title: title.text.trim() || cmd.text.trim() }); }
        onCancelled: ob.cancelled()
    }
}
