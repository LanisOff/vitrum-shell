import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import qs.common
import "../lib/keybinds.js" as KB

Page {
    id: page
    title: "Keyboard & shortcuts"
    subtitle: "Change any shortcut or turn it off, and add your own. Layouts come from niri's config (input → keyboard → xkb)."
    property string filter: ""
    property var catalogue: []
    readonly property var changes: Settings.get("keybinds.changes", {})
    readonly property var own: Settings.get("keybinds.own", [])
    readonly property var list: KB.effective(catalogue, changes, own)
    property string editing: ""        // default keys of the vitrum bind being edited, or "own:<i>", or "own:new"
    FileView {
        path: Quickshell.env("HOME") + "/.config/vitrum/binds.json"
        onLoaded: { try { page.catalogue = JSON.parse(text()); } catch (e) { page.catalogue = []; } }
    }
    readonly property var shown: {
        const q = filter.trim().toLowerCase();
        const vit = list.filter(b => b.own === undefined);
        return q ? vit.filter(b => (b.keys + " " + b.default + " " + b.title + " " + b.section).toLowerCase().indexOf(q) >= 0) : vit;
    }
    property string editFrom: ""       // keys the open editor starts at (the default keys after a clashing Reset / Turn on), else the current ones
    // Restore a bind's default keys; when another bind holds them, open the editor there instead.
    function restore(def) {
        if (KB.conflict(list, def, def, -1)) {
            editFrom = def;
            editing = def;
            return;
        }
        setChange(def, def);
    }
    function setChange(def, keys) {
        const c = Object.assign({}, changes);
        if (keys === def) delete c[def]; else c[def] = keys;
        // drop changes for binds vitrum no longer has
        for (const k in c) if (!catalogue.some(b => b.keys === k)) delete c[k];
        Settings.set("keybinds.changes", c);
    }
    function commit(def, keys) {
        editing = ""; editFrom = "";
        setChange(def, keys);
    }
    function swap(def, curKeys, keys, other) {
        editing = "";
        const c = Object.assign({}, changes);
        if (keys === def) delete c[def]; else c[def] = keys;
        if (curKeys === other.default) delete c[other.default]; else c[other.default] = curKeys;
        Settings.set("keybinds.changes", c);
    }
    function commitOwn(i, e) {
        editing = "";
        setOwn(i, e);
    }
    function setOwn(i, entry) {
        const o = own.slice();
        if (entry === null) o.splice(i, 1); else if (i < 0) o.push(entry); else o[i] = entry;
        Settings.set("keybinds.own", o);
    }
    Section {
        SettingRow {
            label: "All shortcuts"; hint: "The sheet the shell shows on Mod+/ or Mod+. — every binding at a glance."; divider: false
            Capsule { label: "Show"; onClicked: Quickshell.execDetached(["vitrum-ipc", "keybinds", "open"]) }
        }
    }
    Section {
        title: "Layouts"
        Repeater {
            model: Niri.keyboardLayouts
            delegate: SettingRow {
                required property string modelData
                required property int index
                label: modelData
                Icon { name: "check"; visible: index === Niri.keyboardLayoutIndex; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        SettingRow { label: "Switch layout"; hint: "Also from the bar, and on the lock screen."; divider: false
            Rectangle { height: Tokens.islandHeight * 1.05; radius: height / 2; width: kl.implicitWidth + Tokens.padding * 1.6; color: Colors.alpha(Colors.text, 0.06)
                        Label { id: kl; anchors.centerIn: parent; text: "Next" }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Niri.switchLayout(true) } } }
    }
    Rectangle {
        width: parent.width; height: Tokens.islandHeight * 1.2; radius: height / 2
        color: Colors.alpha(Colors.text, 0.06)
        TextInput {
            id: f
            anchors { fill: parent; leftMargin: Tokens.padding; rightMargin: Tokens.padding }
            verticalAlignment: TextInput.AlignVCenter
            font.family: Tokens.fontText; font.pixelSize: Tokens.textSize; color: Colors.text; clip: true
            onTextChanged: page.filter = text
            Label { visible: !f.text; text: "Find a shortcut"; role: "dim"; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    Section {
        title: page.shown.length + " shortcuts"
        Repeater {
            model: page.shown
            delegate: Column {
                id: rowBox
                required property var modelData
                width: parent.width
                SettingRow {
                    width: parent.width
                    label: rowBox.modelData.title
                    hint: rowBox.modelData.changed ? rowBox.modelData.section + " · default " + KB.keyCaps(rowBox.modelData.default).join(" ")
                                                   : rowBox.modelData.section
                    opacity: rowBox.modelData.off ? 0.5 : 1
                    Rectangle {
                        visible: !rowBox.modelData.off
                        anchors.verticalCenter: parent.verticalCenter
                        height: Tokens.islandHeight * 0.95; radius: Tokens.radiusInner; width: kk.implicitWidth + Tokens.padding
                        color: Colors.alpha(Colors.text, 0.08)
                        Label { id: kk; anchors.centerIn: parent; text: KB.keyCaps(rowBox.modelData.keys).join(" "); size: Tokens.textSmall }
                    }
                    Capsule { label: "Edit"; visible: !rowBox.modelData.off; onClicked: { page.editFrom = ""; page.editing = rowBox.modelData.default } }
                    Capsule { label: "Reset"; visible: rowBox.modelData.changed; onClicked: page.restore(rowBox.modelData.default) }
                    Capsule { label: rowBox.modelData.off ? "Turn on" : "Turn off"
                              onClicked: rowBox.modelData.off ? page.restore(rowBox.modelData.default) : page.setChange(rowBox.modelData.default, null) }
                }
                Loader {
                    width: parent.width
                    active: page.editing === rowBox.modelData.default
                    visible: active
                    sourceComponent: KeyEditor {
                        list: page.list; startKeys: page.editFrom || rowBox.modelData.keys; selfDefault: rowBox.modelData.default
                        onSaved: keys => page.commit(rowBox.modelData.default, keys)
                        onSwapped: (keys, other) => page.swap(rowBox.modelData.default, rowBox.modelData.keys, keys, other)
                        onCancelled: page.editing = ""
                    }
                }
            }
        }
    }
    Section {
        title: "Your binds"
        Repeater {
            model: page.list.filter(b => b.own !== undefined)
            delegate: Column {
                id: ownBox
                required property var modelData
                width: parent.width
                SettingRow {
                    width: parent.width
                    label: ownBox.modelData.title; hint: ownBox.modelData.command
                    Label { anchors.verticalCenter: parent.verticalCenter; text: KB.keyCaps(ownBox.modelData.keys).join(" "); size: Tokens.textSmall }
                    Capsule { label: "Edit"; onClicked: page.editing = "own:" + ownBox.modelData.own }
                    Capsule { label: "Remove"; onClicked: page.setOwn(ownBox.modelData.own, null) }
                }
                Loader {
                    width: parent.width
                    active: page.editing === "own:" + ownBox.modelData.own
                    visible: active
                    sourceComponent: OwnBindEditor { list: page.list; index: ownBox.modelData.own; entry: page.own[ownBox.modelData.own]
                                                     onDone: e => page.commitOwn(ownBox.modelData.own, e)
                                                     onCancelled: page.editing = "" }
                }
            }
        }
        SettingRow {
            label: "Add a bind"; hint: "A key combination that runs a command or an app."; divider: false
            Capsule { label: "Add"; onClicked: page.editing = "own:new" }
        }
        Loader {
            width: parent.width
            active: page.editing === "own:new"; visible: active
            sourceComponent: OwnBindEditor { list: page.list; index: -1; entry: ({ keys: "", command: "", title: "" })
                                             onDone: e => page.commitOwn(-1, e)
                                             onCancelled: page.editing = "" }
        }
    }
    Section {
        title: "Layout per app"
        SettingToggle { key: "keyboard.perApp"; label: "Remember the layout for each app"; hint: "Switch to Russian in Telegram once: its windows come back in Russian, the terminal stays in English."; divider: false }
    }
}
