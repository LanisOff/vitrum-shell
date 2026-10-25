import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import qs.common
import "../lib/keybinds.js" as KB
import "../lib/keyboard.js" as Kb

Page {
    id: page
    title: "Keyboard & shortcuts"
    subtitle: "Your keyboard layouts and their order; change any shortcut or turn it off, and add your own."
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
    // Layouts: keyboard.layouts, or niri's config.kdl's own until the first change
    // (vitrum-theme writes the list into generated/input.kdl; niri reloads).
    readonly property string niriDir: Quickshell.env("HOME") + "/.config/vitrum/niri/"
    property string configText: ""
    property string overridesText: ""
    property var rules: []             // xkb's catalogue: { id, name }
    readonly property var layouts: {
        const l = Kb.currentLayouts(Settings.get("keyboard.layouts", []), configText);
        return l.length ? l : Kb.layoutsFromNames(rules, Niri.keyboardLayouts);
    }
    // overrides.kdl's own xkb block wins over what is set here.
    readonly property bool overridden: Kb.parseXkb(overridesText) !== null
    property bool adding: false
    property string layoutQuery: ""
    readonly property var found: Kb.searchLayouts(rules, layoutQuery, layouts, 8)
    function setLayouts(l) { Settings.set("keyboard.layouts", l); }
    // Add a layout from the picker and close it.
    function pick(id) { const l = Kb.addLayout(layouts, id); adding = false; setLayouts(l); }
    FileView { path: page.niriDir + "config.kdl"; onLoaded: page.configText = text() }
    FileView { path: page.niriDir + "overrides.kdl"; watchChanges: true; onFileChanged: reload(); onLoaded: page.overridesText = text() }
    FileView {
        path: "/usr/share/X11/xkb/rules/evdev.lst"
        onLoaded: page.rules = Kb.parseRules(text())
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
            GlassButton { label: "Show"; onClicked: Quickshell.execDetached(["vitrum-ipc", "keybinds", "open"]) }
        }
    }
    Section {
        title: "Layouts"
        SettingRow {
            visible: page.overridden
            label: "overrides.kdl sets the layouts"
            hint: "Its xkb { } block wins over this list: remove it there for these to apply."
        }
        Repeater {
            model: page.layouts
            delegate: SettingRow {
                required property string modelData
                required property int index
                label: Kb.layoutName(page.rules, modelData)
                hint: index === 0 ? "First: the one niri starts with" : ""
                // niri's live list, once it has the same layouts
                Icon { name: "check"; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter
                       visible: Niri.keyboardLayouts.length === page.layouts.length && index === Niri.keyboardLayoutIndex }
                GlassButton { label: "↑"; visible: page.layouts.length > 1; enabled: index > 0
                              onClicked: page.setLayouts(Kb.moveLayout(page.layouts, index, -1)) }
                GlassButton { label: "↓"; visible: page.layouts.length > 1; enabled: index < page.layouts.length - 1
                              onClicked: page.setLayouts(Kb.moveLayout(page.layouts, index, 1)) }
                GlassButton { label: "Remove"; enabled: page.layouts.length > 1
                              onClicked: page.setLayouts(Kb.removeLayout(page.layouts, index)) }
            }
        }
        SettingRow {
            label: "Add a layout"
            hint: page.layouts.length >= Kb.MAX_LAYOUTS ? "Four at most: xkb holds no more." : "Any of xkb's layouts and variants."
            GlassButton { label: page.adding ? "Cancel" : "Add"; enabled: page.adding || page.layouts.length < Kb.MAX_LAYOUTS
                          onClicked: { page.adding = !page.adding; addField.text = ""; if (page.adding) addField.takeFocus(); } }
        }
        Item {
            visible: page.adding
            width: parent.width; height: visible ? addField.height + Tokens.gap * 2 : 0
            Field {
                id: addField
                anchors { left: parent.left; right: parent.right; margins: Tokens.padding; verticalCenter: parent.verticalCenter }
                placeholder: page.rules.length ? "Find a layout: German, de, phonetic…" : "No xkb catalogue (/usr/share/X11/xkb/rules/evdev.lst)"
                onTextChanged: page.layoutQuery = text
                onAccepted: if (page.found.length) page.pick(page.found[0].id)
            }
        }
        Repeater {
            model: page.adding ? page.found : []
            delegate: SettingRow {
                required property var modelData
                label: modelData.name; hint: modelData.id
                // One call into the page: closing the picker destroys this row mid-handler.
                GlassButton { label: "Add"; onClicked: page.pick(modelData.id) }
            }
        }
        SettingRow { label: "Switch layout"; hint: "Also from the bar, and on the lock screen."; divider: false
            GlassButton { label: "Next"; height: Tokens.islandHeight * 1.05; onClicked: Niri.switchLayout(true) } }
    }
    // The filter: a glass field; focus draws an accent ring.
    Surface {
        width: parent.width; height: Tokens.islandHeight * 1.2
        group: "panels"; level: 1
        radius: Tokens.radiusButton
        border.width: f.activeFocus ? 2 : Tokens.hairline
        border.color: f.activeFocus ? Colors.accent : Materials.border(group)
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
        title: page.shown.length + (page.shown.length === 1 ? " shortcut" : " shortcuts")
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
                    GlassButton { label: "Edit"; visible: !rowBox.modelData.off; onClicked: { page.editFrom = ""; page.editing = rowBox.modelData.default } }
                    GlassButton { label: "Reset"; visible: rowBox.modelData.changed; onClicked: page.restore(rowBox.modelData.default) }
                    GlassButton { label: rowBox.modelData.off ? "Turn on" : "Turn off"
                                  onClicked: rowBox.modelData.off ? page.restore(rowBox.modelData.default) : page.setChange(rowBox.modelData.default, null) }
                }
                Loader {
                    // inset like the rows' text, with air below
                    x: Tokens.padding; width: parent.width - Tokens.padding * 2
                    height: active && item ? item.implicitHeight + Tokens.gap : 0
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
                    Rectangle {   // the same key pill as vitrum's binds
                        anchors.verticalCenter: parent.verticalCenter
                        height: Tokens.islandHeight * 0.95; radius: Tokens.radiusInner; width: ok.implicitWidth + Tokens.padding
                        color: Colors.alpha(Colors.text, 0.08)
                        Label { id: ok; anchors.centerIn: parent; text: KB.keyCaps(ownBox.modelData.keys).join(" "); size: Tokens.textSmall }
                    }
                    GlassButton { label: "Edit"; onClicked: page.editing = "own:" + ownBox.modelData.own }
                    GlassButton { label: "Remove"; onClicked: page.setOwn(ownBox.modelData.own, null) }
                }
                Loader {
                    // inset like the rows' text, with air below
                    x: Tokens.padding; width: parent.width - Tokens.padding * 2
                    height: active && item ? item.implicitHeight + Tokens.gap : 0
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
            GlassButton { label: "Add"; onClicked: page.editing = "own:new" }
        }
        Loader {
            x: Tokens.padding; width: parent.width - Tokens.padding * 2
            height: active && item ? item.implicitHeight + Tokens.gap : 0
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
