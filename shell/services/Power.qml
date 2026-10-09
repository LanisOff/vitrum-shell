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

    Timer { interval: 20000; running: true; repeat: true; triggeredOnStart: true
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

    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true
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
    function suspend()   { run(["loginctl", "suspend"]); }
    function hibernate() { run(["loginctl", "hibernate"]); }
    function reboot()    { run(["loginctl", "reboot"]); }
    function shutdown()  { run(["loginctl", "poweroff"]); }

    function run(cmdline) { Quickshell.execDetached(cmdline); }
}
