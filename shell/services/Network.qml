pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

/*
 * Network state for the bar and Control Centre. NetworkManager through
 * Quickshell.Networking when it runs; otherwise (dhcpcd, systemd-networkd…)
 * the link is read from `ip`, read-only — the wired connection still shows,
 * never an error state.
 */
Singleton {
    id: root

    readonly property bool nm: Networking.backend === NetworkBackendType.NetworkManager
    readonly property string backend: nm ? "nm" : "ip"

    // Common view
    property string kind: "none"        // wired | wifi | none
    property string name: ""            // SSID or interface
    property real strength: 0           // wifi 0..1
    property bool online: false
    readonly property bool wifiEnabled: nm ? Networking.wifiEnabled : false
    readonly property var wifiNetworks: _wifiNetworks()

    function setWifiEnabled(on) { if (nm) Networking.wifiEnabled = on; }
    function connect(network, psk) { if (psk) network.connectWithPsk(psk); else network.connect(); }

    // What a network asks for before it lets you in.
    function needsPassword(n) {
        const s = n ? n.security : WifiSecurityType.Open;
        return s === WifiSecurityType.WpaPsk || s === WifiSecurityType.Wpa2Psk || s === WifiSecurityType.Sae;
    }
    function needsLogin(n) {
        const s = n ? n.security : WifiSecurityType.Open;
        return s === WifiSecurityType.WpaEap || s === WifiSecurityType.Wpa2Eap || s === WifiSecurityType.Wpa3SuiteB192
            || s === WifiSecurityType.Leap || s === WifiSecurityType.DynamicWep;
    }
    function secured(n) { return !!n && n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe; }

    /*
     * Join a network the way a person expects: a saved or open one connects,
     * one with a password asks for it (again, if it was wrong), one that needs
     * a login opens Settings → Network on its form.
     *   ask(network, wrong, answer): show a password prompt; answer(password) to try it.
     * Without ask (the shell), the prompt is a system dialog.
     */
    property var _joining: null
    property var _ask: null
    // Settings: the login form for VITRUM_WIFI_JOIN was shown already.
    property bool loginOpened: false
    function forgetAsk(ask) { if (_ask === ask) { _ask = null; _joining = null; } }
    function join(n, ask) {
        if (!n || n.connected) return;
        if (needsLogin(n) && !n.known) { openLogin(n.name); return; }
        _joining = n;
        _ask = ask || _systemAsk;
        if (needsPassword(n) && !n.known) _ask(n, false, psk => n.connectWithPsk(psk));
        else n.connect();
    }
    function openLogin(ssid) { Quickshell.execDetached(["env", "VITRUM_WIFI_JOIN=" + ssid, "vitrum-settings", "--pane", "network"]); }
    function _systemAsk(n, wrong, answer) {
        Prompt.ask({ icon: "wifi-lock", title: "Join “" + n.name + "”",
                     message: wrong ? "That password did not work. Try again." : "This network needs a password.",
                     field: "password", placeholder: "Password", okText: "Join" },
                   (ok, value) => { if (ok && value) answer(value); else root._joining = null; });
    }
    Connections {
        target: root._joining
        function onConnectionFailed(reason) {
            const n = root._joining;
            if (!n || !root._ask) return;
            if (reason === ConnectionFailReason.NoSecrets && root.needsPassword(n)) root._ask(n, true, psk => n.connectWithPsk(psk));
            else if (reason === ConnectionFailReason.NoSecrets && root.needsLogin(n)) root.openLogin(n.name);
            else root._joining = null;
        }
        function onConnectedChanged() { if (root._joining && root._joining.connected) root._joining = null; }
    }

    function _devices() { return nm ? Networking.devices.values : []; }
    function _wifiNetworks() {
        const out = [];
        for (const d of _devices()) {
            if (d.type !== DeviceType.Wifi) continue;
            for (const n of d.networks.values) out.push(n);
        }
        out.sort((a, b) => (b.connected - a.connected) || ((b.signalStrength || 0) - (a.signalStrength || 0)));
        return out;
    }

    function _fromNm() {
        let wired = null, wifi = null;
        for (const d of _devices()) {
            if (d.type === DeviceType.Wired && d.connected) wired = d;
            if (d.type === DeviceType.Wifi && d.connected) wifi = d;
        }
        if (wired) { kind = "wired"; name = wired.name; strength = 1; }
        else if (wifi) {
            const n = wifi.networks.values.find(x => x.connected);
            kind = "wifi"; name = n ? n.name : wifi.name; strength = n ? n.signalStrength : 0;
        } else { kind = "none"; name = ""; strength = 0; }
        online = kind !== "none";
    }

    Timer {
        interval: root.nm ? 3000 : 10000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.nm ? root._fromNm() : ipProc.running = true
    }

    // Fallback: the interface carrying the default route.
    Process {
        id: ipProc
        command: ["sh", "-c", "dev=$(ip -j route show default 2>/dev/null | sed -n 's/.*\"dev\":\"\\([^\"]*\\)\".*/\\1/p' | head -1); [ -n \"$dev\" ] || exit 0; if [ -d /sys/class/net/$dev/wireless ]; then echo \"wifi $dev $(iw dev $dev link 2>/dev/null | sed -n 's/.*SSID: //p') $(awk -v d=$dev '$1==d\":\"{print $3}' /proc/net/wireless)\"; else echo \"wired $dev\"; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(" ");
                if (!p[0]) { root.kind = "none"; root.name = ""; root.online = false; return; }
                root.kind = p[0];
                root.online = true;
                if (p[0] === "wifi") {
                    root.name = p.slice(2, p.length - 1).join(" ") || p[1];
                    const q = parseFloat(p[p.length - 1]);
                    root.strength = isNaN(q) ? 0.5 : Math.max(0, Math.min(1, q / 70));
                } else { root.name = p[1]; root.strength = 1; }
            }
        }
    }
}
