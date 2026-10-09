import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components
import qs.common

Page {
    id: page
    title: "Materials"
    subtitle: "What surfaces are made of: solid, frosted (blur) or glass (refraction). Glass costs the most GPU."
    readonly property var groups: ["bar", "panels", "notifications", "launcher", "lock", "osd", "dock", "dialogs", "widgets", "overlay"]
    Section {
        title: "Everywhere"
        SettingChoice { key: "materials.default"; label: "Default material" }
        SettingChoice { key: "materials.glassPreset"; label: "Glass"; names: ({ thin: "Thin", lens: "Lens", thick: "Thick", crisp: "Crisp" }); divider: false }
    }
    Section {
        title: "Per surface"
        note: "A surface without its own choice uses the default."
        Repeater {
            model: page.groups
            delegate: SettingChoice {
                required property string modelData
                key: "materials.groups." + modelData
                label: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                values: ["", "solid", "frosted", "glass"]
                names: ({ "": "Default", solid: "Solid", frosted: "Frosted", glass: "Glass" })
                setter: v => {
                    const g = Object.assign({}, Settings.get("materials.groups", {}));
                    if (v) g[modelData] = v; else delete g[modelData];
                    Settings.set("materials.groups", g);
                }
            }
        }
    }
    Section {
        title: "Glass, finely"
        note: "Overrides on top of the glass preset. Reset to go back to the preset."
        Repeater {
            model: [
                { k: "refraction-strength", to: 10, step: 0.1 }, { k: "edge-thickness", to: 0.5, step: 0.01 },
                { k: "corner-fan", to: 3, step: 0.1 }, { k: "depth-effect", to: 2, step: 0.1 },
                { k: "glow-weight", to: 2, step: 0.1 }, { k: "edge-lighting", to: 2, step: 0.1 },
                { k: "saturation", to: 2, step: 0.05 }, { k: "adaptive-dim", to: 1, step: 0.01 }, { k: "adaptive-boost", to: 1, step: 0.01 }
            ]
            delegate: SettingSlider {
                required property var modelData
                key: "materials.glassAdvanced." + modelData.k
                label: modelData.k.replace(/-/g, " ").replace(/^./, c => c.toUpperCase())
                from: 0; to: modelData.to; step: modelData.step
            }
        }
        SettingRow {
            label: "Reset to the preset"; divider: false
            Chip_ { text: "Reset"; onClicked: Settings.set("materials.glassAdvanced", {}) }
        }
    }
    component Chip_: Rectangle {
        id: c
        property string text: ""
        signal clicked()
        height: Tokens.islandHeight * 1.05; radius: height / 2; width: cl.implicitWidth + Tokens.padding * 1.6
        color: cm.containsMouse ? Colors.alpha(Colors.text, 0.12) : Colors.alpha(Colors.text, 0.06)
        Label { id: cl; anchors.centerIn: parent; text: c.text }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: c.clicked() }
    }
}
