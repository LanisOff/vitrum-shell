import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import qs.common

Page {
    id: page
    title: "Power & performance"

    // ------------------------------------------------------ Steam theme --
    // The vitrum look in Steam, through Millennium and vitrum-steam-theme.
    // The section has its controls once the steam_theme component is chosen
    // (components.json) or the helper says the theme is in place.
    readonly property string stateDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/vitrum"
    property bool steamChosen: false
    property var steam: ({ millennium: false, installed: false, active: false, steamRunning: false, themeDir: "" })
    property bool steamRead: false          // a status has come back
    property bool steamHelper: true         // vitrum-steam-theme is on the PATH
    property bool steamChanged: false       // something was applied here: a running Steam needs a restart
    property string steamFailed: ""
    property string steamBusy: ""           // install | reinstall | apply, while it runs
    readonly property bool steamReady: steamChosen || steam.installed

    FileView {
        path: page.stateDir + "/components.json"
        printErrors: false                  // no file: nothing chosen yet
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { page.steamChosen = JSON.parse(text()).steam_theme === true; } catch (e) { page.steamChosen = false; } }
        onLoadFailed: page.steamChosen = false
    }
    // Through sh, so a missing helper is an answer (127) and not a process
    // that never starts.
    Command { id: steamStatus }
    function steamRefresh() {
        steamStatus.exec(["sh", "-c", 'command -v vitrum-steam-theme >/dev/null 2>&1 || exit 127; exec vitrum-steam-theme status'], "", (code, out, err) => {
            page.steamHelper = code !== 127;
            page.steamRead = true;
            if (code !== 0) {
                page.steam = { millennium: false, installed: false, active: false, steamRunning: false, themeDir: "" };
                if (code !== 127 && !page.steamFailed) page.steamFailed = err.trim() || "vitrum-steam-theme status failed.";
                return;
            }
            try { page.steam = JSON.parse(out.trim().split("\n").pop()); }
            catch (e) { page.steamFailed = "vitrum-steam-theme status gave nothing to read."; }
        });
    }
    Component.onCompleted: { steamRefresh(); steamSeen = steamNow; }

    // install and reinstall may need sudo (or the AUR helper), so they run
    // in a terminal; the button stays busy until it closes. apply never
    // installs anything and runs quietly.
    Command { id: steamRun }
    function steamDo(cmd) {
        if (page.steamBusy) return;
        page.steamBusy = cmd;
        page.steamFailed = "";
        const script = cmd === "apply" ? 'exec vitrum-steam-theme apply' :
            'if command -v kitty >/dev/null 2>&1; then\n' +
            '  rc=$(mktemp) || exit 1\n' +
            '  kitty --title "Steam theme" -e sh -c \'vitrum-steam-theme "$1"; echo $? > "$2"; echo; echo "Press Enter to close."; read -r _\' _ "$1" "$rc"\n' +
            '  code=$(cat "$rc" 2>/dev/null); rm -f "$rc"\n' +
            '  [ -n "$code" ] || { echo "The terminal closed before it was done." >&2; exit 1; }\n' +
            '  [ "$code" = 0 ] || echo "vitrum-steam-theme $1 failed: the terminal said why." >&2\n' +
            '  exit "$code"\n' +
            'fi\n' +
            'exec vitrum-steam-theme "$1"';
        steamRun.exec(["sh", "-c", 'command -v vitrum-steam-theme >/dev/null 2>&1 || { echo "vitrum-steam-theme is missing: run ./install.sh --only shell." >&2; exit 127; }\n' + script, "_", cmd], "", (code, out, err) => {
            page.steamBusy = "";
            if (code === 0) page.steamChanged = true;
            else page.steamFailed = err.trim().split("\n").pop() || ("vitrum-steam-theme " + cmd + " did not work.");
            page.steamRefresh();
        });
    }

    // A change of steam.theme.* re-runs apply: vitrum-theme only follows the
    // palette while sync is on, and on/off is apply's too.
    // After the settings file is written (Settings writes 400 ms after a set).
    readonly property string steamNow: Settings.ready ? JSON.stringify(Settings.get("steam.theme", {})) : ""
    property string steamSeen: ""
    onSteamNowChanged: {
        if (!steamNow) return;
        if (!steamSeen) { steamSeen = steamNow; return; }
        if (steamNow === steamSeen) return;
        steamSeen = steamNow;
        if (steamReady && steamHelper) steamApply.restart();
    }
    Timer { id: steamApply; interval: 900; onTriggered: page.steamBusy ? restart() : page.steamDo("apply") }

    readonly property string steamLine: !steamHelper ? "vitrum-steam-theme is missing"
        : !steamRead ? "Asking Steam…"
        : (steam.millennium ? "Millennium found" : "Millennium not found") + " · "
          + (!steam.installed ? "theme not installed" : steam.active ? "theme active" : "theme off")
    readonly property string steamHint: !steamHelper ? "Run ./install.sh --only shell to put it back."
        : steamRead && !steam.millennium ? "Reinstall puts Millennium back."
        : steam.steamRunning && steamChanged ? "Restart Steam to apply."
        : ""

    Section {
        title: "Power profile"
        visible: Power.profiles.length > 0
        SettingRow {
            label: "Profile"; divider: false
            Repeater {
                model: Power.profiles
                // The current profile is tinted glass; the others clear.
                delegate: GlassButton {
                    required property string modelData
                    label: modelData === "power-saver" ? "Saver" : modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    primary: Power.profile === modelData
                    labelSize: Tokens.textSmall + 1
                    onClicked: Power.setProfile(modelData)
                }
            }
        }
    }
    Section {
        title: "Battery"
        visible: Power.hasBattery
        SettingRow { label: "Charge"; divider: false; Label { text: [Math.round(Power.percentage) + "%", Power.charging ? "charging" : Power.pluggedIn ? "plugged in" : "", Power.timeRemaining].filter(s => s).join(" · "); role: "dim" } }
    }
    Section {
        title: "Stay awake"
        SettingToggle { key: "awake.media"; label: "Stay awake while something plays"; hint: "Music or a video playing anywhere: the screen does not dim, lock or turn off." }
        SettingToggle { key: "awake.auto"; label: "Stay awake during fullscreen video and games"; hint: "No idle lock while a fullscreen window plays a video or is a game. The coffee cup in Control Centre keeps it awake by hand."; divider: false }
    }
    Section {
        title: "Games"
        SettingToggle { key: "games.mode"; label: "Game mode"; hint: "While a game fills the screen: no animations or blur, notifications held back (critical ones still show), and the game gets gamemode's CPU boost." }
        SettingToggle { key: "games.hud"; needs: "games.mode"; label: "Show MangoHud in game mode"; hint: "FPS, frame time, CPU and GPU load and temperatures, in Steam's games. Mod+Shift+F toggles it." }
        SettingList { key: "games.extra"; label: "Also games"; hint: "Steam games and gamescope are recognised. Add an app id or part of a window title for anything else (e.g. minecraft)." }
    }
    Section {
        title: "Steam theme"
        note: page.steamReady ? "Steam in vitrum's look, through Millennium." : ""
        SettingRow {
            visible: !page.steamReady
            label: "Not installed"
            hint: page.steamHelper ? "Choose “Steam theme” in the installer's games options, or install it now. It may ask for your password in a terminal."
                                   : "Choose “Steam theme” in the installer's games options. vitrum-steam-theme is missing here: run ./install.sh --only shell first."
            divider: page.steamFailed.length > 0
            GlassButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "download"
                label: page.steamBusy === "install" ? "Installing…" : "Install"
                primary: true
                enabled: !page.steamBusy && page.steamHelper
                onClicked: page.steamDo("install")
            }
        }
        SettingRow {
            visible: page.steamReady
            label: page.steamLine
            hint: page.steamHint
            GlassButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "refresh"
                enabled: !page.steamBusy && !steamStatus.busy
                onClicked: page.steamRefresh()
            }
        }
        SettingToggle { visible: page.steamReady; key: "steam.theme.enabled"; label: "vitrum look in Steam"; hint: "Off: Millennium shows Steam's own look." }
        SettingToggle { visible: page.steamReady; key: "steam.theme.sync"; needs: "steam.theme.enabled"; label: "Follow vitrum's colours"; hint: "A new wallpaper, light and dark, the second hue: Steam's colours change with them." }
        SettingRow {
            visible: page.steamReady
            label: "Reinstall"
            hint: "If a Steam update broke Millennium or the theme. It may ask for your password in a terminal."
            divider: page.steamFailed.length > 0
            GlassButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "sync"
                label: page.steamBusy === "reinstall" ? "Reinstalling…" : "Reinstall"
                enabled: !page.steamBusy && page.steamHelper
                onClicked: page.steamDo("reinstall")
            }
        }
        Item {
            visible: page.steamFailed.length > 0
            width: parent.width
            height: failText.implicitHeight + Tokens.gap * 2
            Label {
                id: failText
                anchors { left: parent.left; right: parent.right; margins: Tokens.padding; verticalCenter: parent.verticalCenter }
                text: page.steamFailed
                role: "danger"
                size: Tokens.textSmall
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
        }
    }
    Section {
        title: "Hardware alerts"
        SettingToggle { key: "alerts.enabled"; label: "Warn about the hardware"; hint: "Shown even in a game and in Do not disturb." }
        SettingSlider { key: "alerts.gpu"; needs: "alerts.enabled"; label: "GPU hotter than"; from: 70; to: 100; step: 1; unit: " °C" }
        SettingSlider { key: "alerts.cpu"; needs: "alerts.enabled"; label: "CPU hotter than"; from: 70; to: 105; step: 1; unit: " °C" }
        SettingSlider { key: "alerts.diskPercent"; needs: "alerts.enabled"; label: "A disk fuller than"; from: 70; to: 99; step: 1; unit: " %" }
        SettingSlider { key: "alerts.diskFreeGB"; needs: "alerts.enabled"; label: "Or with less free than"; from: 1; to: 100; step: 1; unit: " GB" }
        SettingToggle { key: "alerts.smart"; needs: "alerts.enabled"; label: "Drive health (SMART)"; hint: "Every six hours, through vitrum's root helper."; divider: false }
    }
}
