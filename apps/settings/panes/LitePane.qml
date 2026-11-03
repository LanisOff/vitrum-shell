import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components
import qs.common
import "../lib/lite.js" as LiteLib

// Lite mode: the heavy effects, cut one by one or all at once (Lite service).
// Each switch below works on its own; lite mode (the master switch, or an
// automatic reason) holds them all on, and their rows say so.
Page {
    id: page
    title: "Lite mode"
    subtitle: "For a slower machine, or a long way from a charger: the effects that cost the most, off one by one or all at once."

    readonly property string held: Lite.active ? LiteLib.heldText(Lite.reason) : ""
    readonly property bool saverKnown: Power.profiles.indexOf("power-saver") >= 0
    readonly property string reasonLine: Lite.reason === "battery" ? "On now: the laptop runs on its battery."
        : Lite.reason === "low" ? "On now: the battery is below " + Math.round(Settings.get("lite.auto.below", 30)) + " %."
        : Lite.reason === "saver" ? "On now: the power profile is Saver."
        : ""

    Section {
        title: "Lite mode"
        SettingToggle {
            key: "lite.enabled"
            label: "Lite mode"
            hint: "Everything below at once. Meant for older or weaker hardware: the shell and niri draw far less, and look plainer."
            divider: page.reasonLine.length > 0
        }
        SettingRow {
            visible: page.reasonLine.length > 0
            label: page.reasonLine
            hint: "It turns itself off again when the reason is gone."
            divider: false
        }
    }

    Section {
        title: "Automatically"
        note: "Everything below goes off with it. niri's part (blur, glass, window animations, shadows, opaque windows) follows a moment later, when it reloads its config."
        SettingToggle {
            visible: Power.hasBattery
            key: "lite.auto.onBattery"
            label: "On battery"
            hint: "Lite mode while the laptop is unplugged, off again once it is plugged in."
        }
        SettingToggle {
            visible: Power.hasBattery
            key: "lite.auto.lowBattery"
            label: "When the battery runs low"
            hint: "Only on battery, and only below the level here."
        }
        SettingSlider {
            visible: Power.hasBattery
            key: "lite.auto.below"
            needs: "lite.auto.lowBattery"
            label: "Battery below"
            from: 5; to: 80; step: 5; unit: " %"
        }
        SettingToggle {
            key: "lite.auto.powerSaver"
            enabled: page.saverKnown
            label: "With the Saver power profile"
            hint: page.saverKnown ? "Whenever the profile is Saver (Power & performance), plugged in or not."
                                  : "No power profiles here: power-profiles-daemon is not running."
            divider: false
        }
    }

    Section {
        title: "What it turns off"
        note: "Each switch also works on its own, with lite mode off. The lock screen keeps its own glass: it is drawn only while locked, over a still picture."
        SettingToggle {
            key: "lite.blur"
            heldBy: page.held
            label: "Plain fills instead of blur"
            hint: "niri blurs what is behind the bar, panels, dock, notifications and widgets whenever it changes: the biggest GPU cost. Instead, the same colours, translucent, without the frost; the player's art is not blurred either."
        }
        SettingToggle {
            key: "lite.glass"
            heldBy: page.held
            label: "No glass refraction"
            hint: "The bent, lit rims of glass surfaces, and the desktop clock's glass digits. Glass becomes frosted (or plain, with the switch above) and the clock's digits are painted."
        }
        SettingToggle {
            key: "lite.light"
            heldBy: page.held
            label: "Still light on lit glass"
            hint: "A piece that is on keeps its frosted light, but it no longer leans toward the pointer or sweeps across when it turns on."
        }
        SettingToggle {
            key: "lite.animations"
            heldBy: page.held
            label: "No shell animations"
            hint: "Panels, the dock, switches and sliders change at once instead of moving and fading, and a new wallpaper has no transition. Every animation redraws the shell for its length."
        }
        SettingToggle {
            key: "lite.windowAnimations"
            heldBy: page.held
            label: "No window animations"
            hint: "niri opens, closes and moves windows and workspaces at once. Fewer frames on a slow GPU; you lose the sense of where things went."
        }
        SettingToggle {
            key: "lite.shadows"
            heldBy: page.held
            label: "No shadows"
            hint: "None under windows or round the overview's workspaces, and none under the desktop clock (its figures are harder to read on a light picture). A window being shared keeps its red edge."
        }
        SettingToggle {
            key: "lite.wallpaper"
            heldBy: page.held
            label: "Still wallpaper"
            hint: "A video wallpaper shows its first frame, and parallax no longer slides with the workspaces: no video decoding, no full-screen redraw on every switch."
        }
        SettingToggle {
            key: "lite.spectrum"
            heldBy: page.held
            label: "No audio spectrum"
            hint: "cava stops: the player and the visualizer widget lose their moving bars. Saves thirty redraws a second while music plays."
        }
        SettingToggle {
            key: "lite.windowGlass"
            heldBy: page.held
            label: "Opaque windows"
            hint: "No glass or frost behind windows (Windows → window materials), an opaque terminal, unfocused windows not dimmed: niri no longer draws what is behind them. With shadows off too, a thin ring shows the focused window."
        }
        SettingToggle {
            key: "lite.polling"
            heldBy: page.held
            label: "Slower system figures"
            hint: "CPU, memory, GPU, network, VPN and camera checks are read three times less often. The Control Centre and the desktop's graphs update more slowly."
            divider: false
        }
    }
}
