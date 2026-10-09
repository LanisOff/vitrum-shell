import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import qs.common

Page {
    id: page
    title: "Keyboard & shortcuts"
    subtitle: "Layouts come from niri's config (input → keyboard → xkb in ~/.config/vitrum/niri/config.kdl)."
    property var binds: []
    property string filter: ""
    FileView {
        path: Quickshell.env("HOME") + "/.config/vitrum/binds.json"
        onLoaded: { try { page.binds = JSON.parse(text()); } catch (e) { page.binds = []; } }
    }
    readonly property var shown: {
        const q = filter.trim().toLowerCase();
        return q ? binds.filter(b => (b.keys + " " + b.title + " " + b.section).toLowerCase().indexOf(q) >= 0) : binds;
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
            delegate: SettingRow {
                required property var modelData
                label: modelData.title || modelData.action
                hint: modelData.section
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: Tokens.islandHeight * 0.95; radius: Tokens.radiusInner; width: kk.implicitWidth + Tokens.padding
                    color: Colors.alpha(Colors.text, 0.08)
                    Label { id: kk; anchors.centerIn: parent; text: modelData.keys; font.family: Tokens.fontMono; size: Tokens.textSmall }
                }
            }
        }
    }
    Section {
        title: "Layout per app"
        SettingToggle { key: "keyboard.perApp"; label: "Remember the layout for each app"; hint: "Switch to Russian in Telegram once: its windows come back in Russian, the terminal stays in English."; divider: false }
    }
}
