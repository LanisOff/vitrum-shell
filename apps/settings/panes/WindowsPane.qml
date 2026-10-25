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
                    // The app's material is tinted glass; the others clear.
                    delegate: GlassButton {
                        required property string modelData
                        label: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                        primary: matRow.modelData.material === modelData
                        labelSize: Tokens.textSmall
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: { const l = page.mats.slice(); l[matRow.index] = Object.assign({}, l[matRow.index], { material: modelData }); page.save(l); }
                    }
                }
                Icon { name: "close"; anchors.verticalCenter: parent.verticalCenter
                       MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const l = page.mats.slice(); l.splice(matRow.index, 1); page.save(l); } } }
            }
        }
        SettingRow {
            label: "Add an app"; hint: "Its app id, as niri shows it (niri msg windows)."; divider: false
            // A glass field, as SettingText's: a rim that lights up while typing.
            Surface {
                anchors.verticalCenter: parent.verticalCenter
                width: Tokens.islandHeight * 7; height: Tokens.islandHeight * 1.1; radius: Tokens.radiusButton
                group: "panels"; level: 1
                border.width: addApp.activeFocus ? 2 : Tokens.hairline
                border.color: addApp.activeFocus ? Colors.accent : Materials.border(group)
                TextInput {
                    id: addApp
                    anchors { fill: parent; leftMargin: Tokens.gap; rightMargin: Tokens.gap }
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Tokens.fontText; font.pixelSize: Tokens.textSize; color: Colors.text; selectionColor: Colors.accent; clip: true
                    // An app already listed keeps its row (a second rule would only fight the first).
                    onAccepted: { const v = text.trim(); if (v && !page.mats.some(m => m.appId === v)) page.save(page.mats.concat([{ appId: v, material: "glass" }])); text = ""; }
                    Label { visible: !addApp.text && !addApp.activeFocus; text: "e.g. org.kde.dolphin"; role: "dim"; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
    Section {
        title: "Picture in picture"
        SettingToggle { key: "windows.pipFollows"; label: "Follows you between workspaces"; hint: "A browser's picture-in-picture video floats in the bottom-right corner and moves along when you switch workspaces on that screen."; divider: false }
    }
}
