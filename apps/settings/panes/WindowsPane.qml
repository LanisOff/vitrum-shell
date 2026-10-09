import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components
import qs.common

Page {
    id: page
    title: "Windows"
    subtitle: "How niri shows windows. The focused one stands out; the others can fade a little."
    readonly property var mats: Settings.get("windows.materials", []) || []
    function save(l) { Settings.set("windows.materials", l); }
    Section {
        SettingChoice { key: "windows.focus"; label: "Focused window"; names: ({ shadow: "Shadow", ring: "Ring", gradient: "Gradient ring" }) }
        SettingSlider { key: "windows.unfocusedOpacity"; label: "Other windows"; from: 0.6; to: 1; step: 0.01 }
        SettingSlider { key: "terminal.opacity"; label: "Terminal background"; from: 0.5; to: 1; step: 0.01; hint: "kitty's opacity — lower lets the window material show through."; divider: false }
    }
    Section {
        title: "Window materials"
        note: "Apps whose windows get a material (their own background must be translucent — kitty's background_opacity, for example). Glass is a frosted lens; Clear is glass without the blur, the most refraction."
        Repeater {
            model: page.mats
            delegate: SettingRow {
                id: matRow
                required property var modelData
                required property int index
                label: modelData.appId || "?"
                Repeater {
                    model: ["solid", "frosted", "glass", "clear"]
                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool on: matRow.modelData.material === modelData
                        height: Tokens.islandHeight; radius: height / 2; width: wl.implicitWidth + Tokens.padding
                        color: on ? Colors.accent : Colors.alpha(Colors.text, 0.06)
                        Label { id: wl; anchors.centerIn: parent; text: modelData.charAt(0).toUpperCase() + modelData.slice(1); role: parent.on ? "onAccent" : "text"; size: Tokens.textSmall }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { const l = page.mats.slice(); l[matRow.index] = Object.assign({}, l[matRow.index], { material: modelData }); page.save(l); } }
                    }
                }
                Icon { name: "close"; anchors.verticalCenter: parent.verticalCenter
                       MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const l = page.mats.slice(); l.splice(matRow.index, 1); page.save(l); } } }
            }
        }
        SettingRow {
            label: "Add an app"; hint: "Its app id, as niri shows it (niri msg windows)."; divider: false
            Rectangle {
                width: Tokens.islandHeight * 7; height: Tokens.islandHeight * 1.1; radius: Tokens.radiusInner
                color: Colors.alpha(Colors.text, 0.06)
                TextInput {
                    id: addApp
                    anchors { fill: parent; leftMargin: Tokens.gap; rightMargin: Tokens.gap }
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Tokens.fontText; font.pixelSize: Tokens.textSize; color: Colors.text; clip: true
                    onAccepted: { const v = text.trim(); if (v) page.save(page.mats.concat([{ appId: v, material: "glass" }])); text = ""; }
                }
            }
        }
    }
    Section {
        title: "Picture in picture"
        SettingToggle { key: "windows.pipFollows"; label: "Follows you between workspaces"; hint: "A browser's picture-in-picture video floats in the bottom-right corner and moves along when you switch workspaces on that screen."; divider: false }
    }
}
