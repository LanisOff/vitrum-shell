import QtQuick
import qs.services
import qs.theme
import qs.components
import "root:/lib/keybinds.js" as KB

// One combination: modifier buttons (tinted while held in the combination), then one key pressed alone (niri takes a
// bound combination before this window sees it; a single key it never takes).
Column {
    id: ed
    property var list: []            // KB.effective(...)
    property string startKeys: ""
    property string selfDefault: ""
    property int selfOwn: -1
    signal saved(string keys)
    signal swapped(string keys, var other)
    signal cancelled()
    spacing: Tokens.gap
    width: parent ? parent.width : 0

    property var mods: ({ super: /(^|\+)Mod\+/.test(startKeys), ctrl: /Ctrl\+/.test(startKeys), alt: /Alt\+/.test(startKeys), shift: /Shift\+/.test(startKeys) })
    property string key: startKeys ? startKeys.split("+").pop() : ""
    readonly property string keys: key ? KB.combo(mods, key) : ""
    readonly property bool modOk: !!(mods.super || mods.ctrl || mods.alt || mods.shift) || /^(F([1-9]|[12][0-9]|3[0-5])|Print|Insert|Delete|Home|End|Page_Up|Page_Down|XF86.*)$/.test(key)
    readonly property var clash: keys ? KB.conflict(list, keys, selfDefault, selfOwn) : null

    Row {
        spacing: Tokens.gap * 0.6
        Repeater {
            model: [{ id: "super", text: "Super" }, { id: "ctrl", text: "Ctrl" }, { id: "alt", text: "Alt" }, { id: "shift", text: "Shift" }]
            delegate: GlassButton {
                required property var modelData
                label: modelData.text
                primary: !!ed.mods[modelData.id]
                onClicked: { const m = Object.assign({}, ed.mods); m[modelData.id] = !m[modelData.id]; ed.mods = m; }
            }
        }
        // The key catcher: a glass field, tinted while it listens for a key.
        Surface {
            id: catcher
            height: Tokens.islandHeight * 1.05; radius: Tokens.radiusButton
            width: Math.max(Tokens.islandHeight * 4, keyLabel.implicitWidth + Tokens.padding * 2)
            group: "panels"; level: 1
            border.width: catcher.activeFocus ? 2 : Tokens.hairline
            border.color: catcher.activeFocus ? Colors.accent : Materials.border(group)
            focus: true
            ShellTint { anchors.fill: parent; radius: parent.radius; active: catcher.activeFocus }
            Label { id: keyLabel; anchors.centerIn: parent; text: catcher.activeFocus ? "Press a key" : (ed.key ? KB.keyCaps(ed.key).join(" ") : "Choose a key"); role: catcher.activeFocus ? "text" : "dim" }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: catcher.forceActiveFocus() }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) { event.accepted = true; ed.cancelled(); return; }
                const n = KB.keyName(event.key, event.text, event.nativeScanCode);
                if (n) { ed.key = n; catcher.focus = false; }
                event.accepted = true;
            }
        }
    }
    Label {
        visible: !!ed.keys
        text: !ed.modOk ? "Add a modifier (Super, Ctrl, Alt or Shift)" : ed.clash ? "Used by " + ed.clash.title : KB.keyCaps(ed.keys).join(" ")
        role: ed.modOk && ed.clash ? "danger" : "dim"
        size: Tokens.textSmall
    }
    Row {
        spacing: Tokens.gap
        GlassButton { label: "Save"; primary: true; visible: !!ed.keys && ed.modOk && !ed.clash; onClicked: ed.saved(ed.keys) }
        GlassButton { label: "Swap"; visible: ed.modOk && !!ed.clash && ed.clash.own === undefined && ed.selfDefault.length > 0; onClicked: ed.swapped(ed.keys, ed.clash) }
        GlassButton { label: "Cancel"; onClicked: ed.cancelled() }
    }
    Component.onCompleted: catcher.forceActiveFocus()
}
