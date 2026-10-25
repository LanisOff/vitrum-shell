import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import qs.common
import "../lib/color.js" as Col

Page {
    id: page
    title: "Appearance"
    subtitle: "Light and dark, colours and density. Everything applies at once."

    // ---------------------------------------------------- Vesktop theme --
    // The vitrum look in Vesktop (Discord), through vitrum-vesktop-theme, as
    // the Steam theme is in Power & performance. The section has its controls
    // once the vesktop_theme component is chosen (components.json) or the
    // helper says the theme is in place.
    readonly property string stateDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/vitrum"
    property bool vesktopChosen: false
    property var vesktop: ({ vesktop: false, installed: false, active: false, running: false, themeDir: "" })
    property bool vesktopRead: false        // a status has come back
    property bool vesktopHelper: true       // vitrum-vesktop-theme is on the PATH
    property bool vesktopChanged: false     // something was applied here: a running Vesktop needs a restart
    property string vesktopFailed: ""
    property string vesktopBusy: ""         // install | reinstall | apply, while it runs
    readonly property bool vesktopReady: vesktopChosen || vesktop.installed

    FileView {
        path: page.stateDir + "/components.json"
        printErrors: false                  // no file: nothing chosen yet
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { page.vesktopChosen = JSON.parse(text()).vesktop_theme === true; } catch (e) { page.vesktopChosen = false; } }
        onLoadFailed: page.vesktopChosen = false
    }
    // Through sh, so a missing helper is an answer (127) and not a process
    // that never starts.
    Command { id: vesktopStatus }
    function vesktopRefresh() {
        vesktopStatus.exec(["sh", "-c", 'command -v vitrum-vesktop-theme >/dev/null 2>&1 || exit 127; exec vitrum-vesktop-theme status'], "", (code, out, err) => {
            page.vesktopHelper = code !== 127;
            page.vesktopRead = true;
            if (code !== 0) {
                page.vesktop = { vesktop: false, installed: false, active: false, running: false, themeDir: "" };
                if (code !== 127 && !page.vesktopFailed) page.vesktopFailed = err.trim() || "vitrum-vesktop-theme status failed.";
                return;
            }
            try { page.vesktop = JSON.parse(out.trim().split("\n").pop()); }
            catch (e) { page.vesktopFailed = "vitrum-vesktop-theme status gave nothing to read."; }
        });
    }
    Component.onCompleted: { vesktopRefresh(); vesktopSeen = vesktopNow; }

    // install and reinstall run quietly; one that needs a terminal (exit 2)
    // runs again in one, and the button stays busy until it closes.
    Command { id: vesktopRun }
    function vesktopDo(cmd) {
        if (page.vesktopBusy) return;
        page.vesktopBusy = cmd;
        page.vesktopFailed = "";
        const script = cmd === "apply" ? 'exec vitrum-vesktop-theme apply' :
            'vitrum-vesktop-theme "$1"; code=$?\n' +
            '[ "$code" = 2 ] && command -v kitty >/dev/null 2>&1 || exit "$code"\n' +
            'rc=$(mktemp) || exit 1\n' +
            'kitty --title "Vesktop theme" -e sh -c \'vitrum-vesktop-theme "$1"; echo $? > "$2"; echo; echo "Press Enter to close."; read -r _\' _ "$1" "$rc"\n' +
            'code=$(cat "$rc" 2>/dev/null); rm -f "$rc"\n' +
            '[ -n "$code" ] || { echo "The terminal closed before it was done." >&2; exit 1; }\n' +
            '[ "$code" = 0 ] || echo "vitrum-vesktop-theme $1 failed: the terminal said why." >&2\n' +
            'exit "$code"';
        vesktopRun.exec(["sh", "-c", 'command -v vitrum-vesktop-theme >/dev/null 2>&1 || { echo "vitrum-vesktop-theme is missing: run ./install.sh --only shell." >&2; exit 127; }\n' + script, "_", cmd], "", (code, out, err) => {
            page.vesktopBusy = "";
            if (code === 0) page.vesktopChanged = true;
            else page.vesktopFailed = err.trim().split("\n").pop() || ("vitrum-vesktop-theme " + cmd + " did not work.");
            page.vesktopRefresh();
        });
    }

    // A change of vesktop.theme.* re-runs apply: vitrum-theme only follows
    // the palette while sync is on, and on/off is apply's too. After the
    // settings file is written (Settings writes 400 ms after a set).
    readonly property string vesktopNow: Settings.ready ? JSON.stringify(Settings.get("vesktop.theme", {})) : ""
    property string vesktopSeen: ""
    onVesktopNowChanged: {
        if (!vesktopNow) return;
        if (!vesktopSeen) { vesktopSeen = vesktopNow; return; }
        if (vesktopNow === vesktopSeen) return;
        vesktopSeen = vesktopNow;
        if (vesktopReady && vesktopHelper) vesktopApply.restart();
    }
    Timer { id: vesktopApply; interval: 900; onTriggered: page.vesktopBusy ? restart() : page.vesktopDo("apply") }

    readonly property string vesktopLine: !vesktopHelper ? "vitrum-vesktop-theme is missing"
        : !vesktopRead ? "Asking Vesktop…"
        : (vesktop.vesktop ? "Vesktop found" : "Vesktop not found") + " · "
          + (!vesktop.installed ? "theme not installed" : vesktop.active ? "theme active" : "theme off")
    readonly property string vesktopHint: !vesktopHelper ? "Run ./install.sh --only shell to put it back."
        : vesktopRead && !vesktop.vesktop ? "Install Vesktop, start it once, then Reinstall."
        : vesktop.running && vesktopChanged ? "Restart Vesktop to apply."
        : ""
    /// A time of day as HH:MM ("7:5" is not one; "730", "7.30" and "7:30" are
    /// 07:30), or undefined: "25:99" was saved and Sun read it as never.
    function hhmm(t) {
        const m = /^\s*(\d{1,2})[:.]?(\d{2})\s*$/.exec(String(t));
        if (!m || Number(m[1]) > 23 || Number(m[2]) > 59) return undefined;
        return (m[1].length < 2 ? "0" : "") + m[1] + ":" + m[2];
    }
    Section {
        title: "Scheme"
        SettingChoice { key: "scheme.mode"; names: ({ auto: "Automatic", light: "Light", dark: "Dark" }); hint: "Automatic follows sunrise and sunset where you are (Date, time & weather), otherwise the times below." }
        SettingText { key: "scheme.light"; label: "Light from"; placeholder: "07:00"; fieldWidth: Tokens.islandHeight * 3; normalize: t => page.hhmm(t) }
        SettingText { key: "scheme.dark"; label: "Dark from"; placeholder: "19:30"; fieldWidth: Tokens.islandHeight * 3; divider: false; normalize: t => page.hhmm(t) }
    }
    Section {
        title: "Colours"
        SettingChoice { key: "palette.source"; names: ({ wallpaper: "From the wallpaper", preset: "Preset" }) }
        SettingChoice { key: "palette.preset"; hint: "Used when the source is a preset, or when the wallpaper cannot be read." }
        SettingColor { key: "palette.accent"; label: "Accent"; hint: "Overrides the palette's accent; × keeps the palette's own."; divider: false }
    }
    // The second colour: the accent's hue turned look.dichroic.shift degrees,
    // for the pairs in rings, meters and graphs. The shell
    // re-runs vitrum-theme on the change (palette.json's accent2, niri's focus
    // ring); the preview computes the pair itself, so it follows the slider.
    Section {
        id: dich
        title: "Second colour"
        readonly property real shift: Number(Settings.get("look.dichroic.shift", -100))
        readonly property color second: {
            const c = Col.dichroic(Colors.accent.hslHue, dich.shift, Colors.dark);
            return Qt.hsla(c.h, c.s, c.l, 1);
        }
        SettingSlider {
            key: "look.dichroic.shift"; label: "Second hue"; from: -180; to: 180; step: 1; unit: "°"
            hint: "Rings, meters and graphs blend from the accent to this second colour: how far round the colour wheel it turns. A Gradient ring on the focused window (Windows) follows."
        }
        SettingRow {
            label: "Preview"; divider: false
            // The pair as it shows in the shell: a ring and a meter.
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.gap * 1.5
                Ring {
                    width: Math.round(Tokens.islandHeight * 1.3); height: width
                    anchors.verticalCenter: parent.verticalCenter
                    value: 0.68; thickness: Math.max(4, width * 0.12)
                    color: Colors.accent; color2: dich.second
                }
                Meter {
                    width: Tokens.islandHeight * 4.5
                    anchors.verticalCenter: parent.verticalCenter
                    value: 0.72; color: Colors.accent; color2: dich.second
                }
            }
            GlassButton {
                label: "Default"
                anchors.verticalCenter: parent.verticalCenter
                enabled: dich.shift !== -100
                onClicked: Settings.set("look.dichroic.shift", -100)
            }
        }
    }
    Section {
        title: "Density"
        SettingChoice { key: "density"; hint: "Sizes of bars, panels, gaps and text."; divider: false }
    }
    Section {
        title: "Other apps"
        SettingToggle { key: "toolkits.kde"; label: "Colour KDE apps"; hint: "Dolphin, Kate, Okular… take the palette through kdeglobals. Off leaves kdeglobals to you (Plasma, your own scheme)." }
        SettingToggle { key: "toolkits.gtk"; label: "Colour GTK apps"; hint: "GTK 3 and 4 apps (pavucontrol, file dialogs…) take the palette through adw-gtk3. Off leaves your GTK theme and files alone."; divider: false }
    }
    Section {
        title: "Vesktop theme"
        note: page.vesktopReady ? "Discord, in Vesktop, in vitrum's look." : ""
        SettingRow {
            visible: !page.vesktopReady
            label: "Not installed"
            hint: page.vesktopHelper ? "Choose “Vesktop theme” in the installer's tools, or install it now. Vesktop itself must be installed."
                                     : "Choose “Vesktop theme” in the installer's tools. vitrum-vesktop-theme is missing here: run ./install.sh --only shell first."
            divider: page.vesktopFailed.length > 0
            GlassButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "download"
                label: page.vesktopBusy === "install" ? "Installing…" : "Install"
                primary: true
                enabled: !page.vesktopBusy && page.vesktopHelper
                onClicked: page.vesktopDo("install")
            }
        }
        SettingRow {
            visible: page.vesktopReady
            label: page.vesktopLine
            hint: page.vesktopHint
            GlassButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "refresh"
                enabled: !page.vesktopBusy && !vesktopStatus.busy
                onClicked: page.vesktopRefresh()
            }
        }
        SettingToggle { visible: page.vesktopReady; key: "vesktop.theme.enabled"; label: "vitrum look in Vesktop"; hint: "Off: Vesktop shows Discord's own look." }
        SettingToggle { visible: page.vesktopReady; key: "vesktop.theme.sync"; needs: "vesktop.theme.enabled"; label: "Follow vitrum's colours"; hint: "A new wallpaper, light and dark, the second hue: Vesktop's colours change with them." }
        SettingRow {
            visible: page.vesktopReady
            label: "Reinstall"
            hint: "If a Vesktop or Vencord update dropped the theme."
            divider: page.vesktopFailed.length > 0
            GlassButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "sync"
                label: page.vesktopBusy === "reinstall" ? "Reinstalling…" : "Reinstall"
                enabled: !page.vesktopBusy && page.vesktopHelper
                onClicked: page.vesktopDo("reinstall")
            }
        }
        Item {
            visible: page.vesktopFailed.length > 0
            width: parent.width
            height: vesktopFailText.implicitHeight + Tokens.gap * 2
            Label {
                id: vesktopFailText
                anchors { left: parent.left; right: parent.right; margins: Tokens.padding; verticalCenter: parent.verticalCenter }
                text: page.vesktopFailed
                role: "danger"
                size: Tokens.textSmall
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
        }
    }
}
