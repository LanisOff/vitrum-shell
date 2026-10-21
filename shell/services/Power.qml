pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

/*
 * Battery, power profiles, backlight, and the session actions.
 *
 * UPower comes from Quickshell directly. Backlight goes through brightnessctl
 * because reading /sys works but writing to it needs either udev rules or a
 * setuid helper, and brightnessctl already ships one.
 */
Singleton {
    id: root

    // ---------------------------------------------------------- battery ---

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool hasBattery: device && device.isLaptopBattery
    readonly property real percentage: device ? device.percentage * 100 : 100
    readonly property bool charging: device ? device.state === UPowerDeviceState.Charging : false
    readonly property bool pluggedIn: UPower.onBattery === false
    readonly property real timeToEmpty: device ? device.timeToEmpty : 0
    readonly property real timeToFull: device ? device.timeToFull : 0
    readonly property real healthPercentage: device ? device.healthPercentage : 0

    readonly property string timeRemaining: {
        const secs = charging ? timeToFull : timeToEmpty;
        if (!secs || secs <= 0) return "";
        const h = Math.floor(secs / 3600), m = Math.floor((secs % 3600) / 60);
        if (h > 0) return h + ":" + (m < 10 ? "0" : "") + m;
        return m + " min";
    }

    readonly property bool low: hasBattery && !charging && percentage <= 20
    readonly property bool critical: hasBattery && !charging && percentage <= 10

    // --------------------------------------------------- power profiles ---

    property string profile: "balanced"       // power-saver | balanced | performance
    property var profiles: []

    Process {
        id: profileRead
        command: ["sh", "-c",
            "powerprofilesctl get 2>/dev/null; echo '---'; powerprofilesctl list 2>/dev/null | grep -oE '^[* ] [a-z-]+' | tr -d '* '"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.split("---");
                root.profile = (p[0] || "").trim() || "balanced";
                root.profiles = (p[1] || "").trim().split("\n").filter(s => s.length > 0);
            }
        }
    }

    function setProfile(name) {
        run(["powerprofilesctl", "set", name]);
        profile = name;
    }

    // Not while a game runs (nothing shows it then); read again after.
    Timer { interval: 20000; running: !GameMode.active; repeat: true; triggeredOnStart: true
            onTriggered: profileRead.running = true }

    // -------------------------------------------------------- backlight ---

    property real brightness: 1.0
    property bool hasBacklight: false

    Process {
        id: brightRead
        command: ["sh", "-c", "brightnessctl -m -c backlight 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                // device,class,current,percent%,max
                const f = text.trim().split(",");
                if (f.length >= 4) {
                    root.hasBacklight = true;
                    root.brightness = (parseInt(f[3]) || 0) / 100;
                } else {
                    root.hasBacklight = false;
                }
            }
        }
    }

    // Read once; then polled only where there is a backlight (a desktop has
    // none: that was a brightnessctl every five seconds for nothing), and not
    // while a game runs.
    Component.onCompleted: brightRead.running = true
    Timer { interval: 5000; running: root.hasBacklight && !GameMode.active; repeat: true; triggeredOnStart: true
            onTriggered: brightRead.running = true }

    signal feedback(string kind)

    function setBrightness(v) {
        const pct = Math.round(Math.max(0.01, Math.min(1, v)) * 100);
        brightness = pct / 100;
        run(["brightnessctl", "-q", "-c", "backlight", "set", pct + "%"]);
        feedback("brightness");
    }

    function stepBrightness(delta) {
        // Below 10% the eye notices absolute steps far more than relative
        // ones, so the step shrinks near the bottom the way macOS does.
        const cur = brightness;
        const step = cur <= 0.1 ? 0.02 : 0.05;
        setBrightness(cur + (delta > 0 ? step : -step));
    }

    // --------------------------------------------------------- session ---

    function lock()      { run(["vitrum-ipc", "lock", "lock"]); }
    function logout()    { run([Niri.bin, "msg", "action", "quit", "--skip-confirmation"]); }
    function suspend()   { _logind("Suspend", "suspend", "zzz"); }
    function hibernate() { _logind("Hibernate", "hibernate", "ZZZ"); }
    function reboot()    { _logind("Reboot", "reboot", "reboot"); }
    function shutdown()  { _logind("PowerOff", "poweroff", "poweroff"); }

    // logind over D-Bus, which systemd-logind and elogind both answer — their
    // loginctl verbs differ (systemd's has no poweroff, reboot or suspend, so
    // these did nothing on Arch). interactive=true: polkit may ask first (another
    // user logged in), through the shell's prompt. systemctl and elogind's
    // loginctl after it, should D-Bus fail.
    //
    // Last, where there is no logind at all (Void with seatd only): the init's
    // own tool — poweroff and reboot, Void's zzz and ZZZ for sleep — through
    // sudo or doas, and only if they let it through without a password (-n:
    // nothing could ask). Only without logind: where it is there and polkit
    // said no (you cancelled its prompt), that no stands. When none of it can
    // (exit 3), say so: otherwise the button would just do nothing.
    function _logind(method, verb, tool) {
        if (action.running) return;
        action.label = ({ poweroff: "power off", reboot: "restart", suspend: "sleep", hibernate: "hibernate" })[verb] || verb;
        action.command = ["sh", "-c", 'dbus-send --system --print-reply --reply-timeout=120000 --dest=org.freedesktop.login1 /org/freedesktop/login1 '
             + '"org.freedesktop.login1.Manager.$1" boolean:true >/dev/null 2>&1 || systemctl "$2" 2>/dev/null || loginctl "$2" 2>/dev/null || { '
             + 'dbus-send --system --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.NameHasOwner '
             + 'string:org.freedesktop.login1 2>/dev/null | grep -q "boolean true" && exit 1; '
             + 'if [ "$(id -u)" = 0 ]; then "$3"; elif command -v sudo >/dev/null; then sudo -n "$3"; '
             + 'elif command -v doas >/dev/null; then doas -n "$3"; else false; fi || exit 3; }', "_", method, verb, tool];
        action.running = true;
    }
    Process {
        id: action
        property string label: ""
        onExited: (code) => {
            if (code === 3)
                Notifs.inject("Power", "Could not " + label,
                              "There is no logind (elogind) to ask, and sudo or doas want a password for it. "
                              + "Start elogind, or allow this without a password.");
        }
    }

    function run(cmdline) { Quickshell.execDetached(cmdline); }
}
