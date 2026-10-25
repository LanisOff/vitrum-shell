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
    // The glass presets' values (tools/vitrum_theme GLASS_PRESETS, in GLASS_KEYS
    // order): an unset slider shows what the preset gives, not 0.
    readonly property var presets: ({
        thin:  [2.4, 0.10, 1.3, 0.8, 0.5, 0.4, 1.05, 0.15, 0.15],
        lens:  [4.8, 0.12, 1.5, 1.0, 0.8, 0.5, 0.95, 0.15, 0.15],
        thick: [6.0, 0.18, 1.6, 1.0, 0.9, 0.6, 1.00, 0.20, 0.20],
        crisp: [3.6, 0.12, 1.2, 0.6, 0.6, 0.3, 1.00, 0.12, 0.12]
    })
    readonly property var preset: presets[Settings.get("materials.glassPreset", "lens")] || presets.lens
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
                // "Default" is stored as "": dropping the key let the shipped
                // groups (bar, lock, launcher: glass) come back through the
                // defaults, so those three could never follow the default.
                setter: v => {
                    const g = Object.assign({}, Settings.get("materials.groups", {}));
                    g[modelData] = v;
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
                required property int index
                key: "materials.glassAdvanced." + modelData.k
                fallback: page.preset[index]
                label: modelData.k.replace(/-/g, " ").replace(/^./, c => c.toUpperCase())
                from: 0; to: modelData.to; step: modelData.step
            }
        }
        SettingRow {
            label: "Reset to the preset"; divider: false
            GlassButton { label: "Reset"; onClicked: Settings.set("materials.glassAdvanced", {}) }
        }
    }
}
