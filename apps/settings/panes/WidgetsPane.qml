import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components
import qs.common
import "../lib/widgets.js" as W

// Widgets are arranged on the desktop itself, in the editor; here: the way
// in, what is where, and the widgets you made (script widgets live in
// widgets.custom, QML ones in ~/.config/vitrum/widgets).
Page {
    id: page
    title: "Widgets"
    subtitle: "Widgets live on the desktop, per screen. Add, arrange and set them up in the editor."
    readonly property var items: Settings.get("widgets.items", []) || []
    readonly property var scripts: Settings.get("widgets.custom", []) || []
    function nameOf(type) {
        const s = String(type || "");
        if (s.indexOf("script:") === 0) { const c = page.scripts.find(x => "script:" + x.id === s); return c ? c.name : "Script widget"; }
        if (s.indexOf("qml:") === 0) return s.slice(4) + " (QML)";
        return W.meta(s).name;
    }
    Section {
        SettingRow {
            label: "Edit widgets"; hint: "The desktop shrinks beside a gallery: click or drag to add, drag to move, the corner to resize. Also Mod+Alt+W, or right-click a widget."; divider: false
            GlassButton { label: "Open the editor"; primary: true; onClicked: Quickshell.execDetached(["vitrum-ipc", "widgets", "edit"]) }
        }
    }
    Section {
        title: "On the desktop"
        Label { visible: page.items.length === 0; text: "No widgets yet."; role: "dim"; padding: Tokens.padding }
        Repeater {
            model: page.items
            delegate: SettingRow {
                required property var modelData
                required property int index
                label: page.nameOf(modelData.type)
                hint: (modelData.output === "*" ? "every screen" : modelData.output || "?") + " · " + Math.round(modelData.x || 0) + ", " + Math.round(modelData.y || 0) + " · " + Math.round(modelData.w || 0) + "×" + Math.round(modelData.h || 0)
                Icon { name: "close"; anchors.verticalCenter: parent.verticalCenter
                       MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const l = page.items.slice(); l.splice(index, 1); Settings.set("widgets.items", l); } } }
            }
        }
    }
    Section {
        title: "Your widgets"
        Label {
            width: parent.width; padding: Tokens.padding; wrapMode: Text.WordWrap; elide: Text.ElideNone; role: "dim"; size: Tokens.textSmall + 1
            text: "Script widgets run a command and show what it prints; make them in the editor's Custom tab. QML widgets are folders in ~/.config/vitrum/widgets (a manifest.json and a Widget.qml)."
        }
        Repeater {
            model: page.scripts
            delegate: SettingRow {
                required property var modelData
                required property int index
                label: modelData.name || modelData.id
                hint: (modelData.command || "") + " · every " + (modelData.interval || 10) + " s"
                Icon { name: "trash"; anchors.verticalCenter: parent.verticalCenter
                       MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                   // The widget's copies on the desktop go with it (else "Missing widget").
                                   onClicked: {
                                       const type = "script:" + modelData.id;
                                       if (page.items.some(i => i.type === type)) Settings.set("widgets.items", page.items.filter(i => i.type !== type));
                                       Settings.set("widgets.custom", page.scripts.filter(s => s.id !== modelData.id));
                                   } } }
            }
        }
        SettingRow {
            label: "Widgets folder"; hint: "~/.config/vitrum/widgets"; divider: false
            GlassButton { label: "Open"; onClicked: Quickshell.execDetached(["sh", "-c", 'mkdir -p "$HOME/.config/vitrum/widgets" && exec xdg-open "$HOME/.config/vitrum/widgets"']) }
        }
    }
}
