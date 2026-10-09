import QtQuick
import Quickshell
import qs.services

// Every service loads without niri, NetworkManager or a session bus being
// required; compositor-dependent parts report unavailable instead of failing.
ShellRoot {
    function check(name, ok, why) { console.log((ok ? " PASS " : " FAIL ") + name + (ok ? "" : ": " + why)); }
    Component.onCompleted: {
        // touch every singleton
        const all = [Settings, Sun, Niri, Audio, Media, Notifs, Weather, Apps, Clipboard, Emoji, SysInfo, Power, Network, Bluetooth, Polkit, Sounds, Idle, UiState];
        check("all services construct", all.every(s => s !== null && s !== undefined), "");
        SysInfo.subscribe();
    }
    Timer {
        interval: 5000; running: true
        onTriggered: {
            check("niri unavailable outside vitrum", Niri.available === false, Niri.available);
            check("niri binary is niri", Niri.bin === "niri", Niri.bin);
            check("network fallback backend without NetworkManager", Network.backend === "ip", Network.backend);
            check("network reports the wired link", Network.kind === "wired" && Network.online, Network.kind + "/" + Network.online);
            check("cpu usage measured", SysInfo.cpuUsage >= 0 && SysInfo.cpuUsage <= 1, SysInfo.cpuUsage);
            check("nvidia gpu read", SysInfo.gpuAvailable, SysInfo.gpuAvailable);
            check("sun decided", typeof Sun.isDay === "boolean", typeof Sun.isDay);
            check("apps listed", Apps.all.length > 10, Apps.all.length);
            console.log(" DONE"); Qt.quit();
        }
    }
}
