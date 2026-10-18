import QtQuick
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import qs.common

// Wi-Fi (the list, a password when one is needed, a hidden network or one
// with a login), the wired connection, each connection's addressing, and VPN
// profiles. The list is Quickshell's; the rest goes through vitrum-net
// (NetworkManager), passwords on its stdin.
Page {
    id: page
    title: "Network"
    subtitle: Network.nm ? "" : "NetworkManager is not running: the connection is shown from the system, and Wi-Fi is managed by whatever set it up."

    // Saved connections (vitrum-net list), refreshed after every change.
    property var saved: []
    readonly property var wired: saved.filter(c => c.kind === "ethernet")
    readonly property var vpns: saved.filter(c => c.kind === "vpn" || c.kind === "wireguard")
    function savedWifi(ssid) { return saved.find(c => c.kind === "wifi" && c.name === ssid) || null; }
    // Rows are rebuilt only when the list really changed.
    property string _savedText: ""
    Process {
        id: lister
        running: Network.nm
        command: ["vitrum-net", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text === page._savedText) return;
                page._savedText = text;
                try { page.saved = JSON.parse(text); } catch (e) { page.saved = []; }
            }
        }
    }
    Timer { interval: 4000; running: Network.nm; repeat: true; onTriggered: lister.running = true }
    // up, down, delete, set, import, wifi-add, show: in turn, each answer whole.
    Command { id: act }
    function run(args, after, input) {
        act.exec(["vitrum-net"].concat(args), input || "", (code, out, err) => {
            lister.running = true;
            if (after) after(code === 0, err.trim(), out);
        });
    }

    // Opened from the shell for a network that needs a login — once per
    // window, not again whenever this page is shown.
    Component.onCompleted: {
        const s = Quickshell.env("VITRUM_WIFI_JOIN");
        if (s && !Network.loginOpened) { Network.loginOpened = true; join.openFor(s, false, true); }
    }
    // A page that is gone cannot show a password prompt any more.
    Component.onDestruction: Network.forgetAsk(askPassword)
    /// Tests: open the forms (qs ipc call network join <ssid> <enterprise> / password <ssid> / details <name>).
    IpcHandler {
        target: "network"
        function join(ssid: string, enterprise: bool): void { page.joinForm(ssid, enterprise); }
        function password(ssid: string): void { page.askPassword({ name: ssid }, false, () => {}); }
        function details(name: string): void { const c = page.saved.find(x => x.name === name); if (c) page.detailsForm(c); }
    }
    function joinForm(ssid, enterprise) { join.openFor(ssid, !ssid, enterprise); }
    function detailsForm(c) { details.openFor(c); }

    Section {
        title: "Connection"
        SettingRow {
            label: Network.online ? (Network.kind === "wifi" ? "Wi-Fi" : "Wired") : "Offline"
            hint: Network.online ? Network.name : "No connection"
            divider: false
            Icon { name: Network.kind === "wired" ? "ethernet" : Network.kind === "wifi" ? "wifi" : "network-off"; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    Section {
        title: "Wi-Fi"
        visible: Network.nm
        SettingRow {
            label: "Wi-Fi"
            Toggle { checked: Network.wifiEnabled; onToggled: Network.setWifiEnabled(!Network.wifiEnabled) }
        }
        Repeater {
            model: Network.wifiEnabled ? Network.wifiNetworks : []
            delegate: SettingRow {
                id: net
                required property var modelData
                readonly property var conn: page.savedWifi(modelData.name)
                label: modelData.name || "?"
                hint: modelData.connected ? "Connected" : modelData.stateChanging ? "Connecting…" : modelData.known ? "Saved"
                    : Network.needsLogin(modelData) ? "Needs a sign-in" : ""
                Icon { visible: Network.secured(net.modelData); name: "lock"; size: Tokens.iconSize * 0.8; color: Colors.textDim; anchors.verticalCenter: parent.verticalCenter }
                Icon { name: "wifi"; opacity: 0.4 + 0.6 * (net.modelData.signalStrength || 0); anchors.verticalCenter: parent.verticalCenter }
                Icon {
                    visible: !!net.conn
                    name: "settings"; color: Colors.textDim; anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: details.openFor(net.conn) }
                }
                MouseArea {
                    parent: net; anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const n = net.modelData;
                        if (n.connected) return;
                        if (Network.needsLogin(n) && !n.known) join.openFor(n.name, false, true);
                        else Network.join(n, page.askPassword);
                    }
                }
            }
        }
        SettingRow {
            visible: Network.wifiEnabled
            label: "Other network…"; hint: "A hidden network, or one to set up by hand"; divider: false
            Capsule { label: "Join…"; onClicked: join.openFor("", true, false) }
        }
    }

    Section {
        title: "Wired"
        visible: Network.nm && page.wired.length > 0
        Repeater {
            model: page.wired
            delegate: SettingRow {
                required property var modelData
                required property int index
                label: modelData.name
                hint: modelData.active ? "Connected" + (modelData.device ? " · " + modelData.device : "") : "Not connected"
                divider: index < page.wired.length - 1
                Capsule { label: "Details…"; anchors.verticalCenter: parent.verticalCenter; onClicked: details.openFor(modelData) }
            }
        }
    }

    Section {
        title: "VPN"
        visible: Network.nm
        note: "OpenVPN profiles need NetworkManager's OpenVPN plugin; WireGuard works as it is."
        Label { visible: page.vpns.length === 0; text: "No VPN yet. Import a profile your provider gave you."; role: "dim"; padding: Tokens.padding }
        Repeater {
            model: page.vpns
            delegate: SettingRow {
                id: vpn
                required property var modelData
                label: modelData.name
                hint: (modelData.kind === "wireguard" ? "WireGuard" : "OpenVPN / VPN") + (modelData.active ? " · connected" : "")
                Icon {
                    name: "trash"; color: Colors.textDim; anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: remove.ask(vpn.modelData) }
                }
                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: vpn.modelData.active
                    onToggled: page.run([vpn.modelData.active ? "down" : "up", vpn.modelData.uuid], (ok, err) => { if (!ok) page.problem = err; })
                }
            }
        }
        SettingRow {
            label: "Import a profile"; hint: page.problem; divider: false
            Capsule { icon: "download"; label: "Choose file…"; onClicked: vpnFile.open() }
        }
    }
    property string problem: ""
    FileDialog {
        id: vpnFile
        title: "VPN profile"
        nameFilters: ["VPN profiles (*.ovpn *.conf)", "All files (*)"]
        onAccepted: page.run(["import", decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""))],
                             (ok, err) => page.problem = ok ? "" : err)
    }

    // ------------------------------------------------------------ sheets ---

    // The password for a network in the list (asked again when it was wrong).
    function askPassword(n, wrong, answer) { pw.answer = answer; pw.network = n.name; pw.open(); pw.error = wrong ? "That password did not work. Try again." : ""; pwField.text = ""; pwField.takeFocus(); }
    Sheet {
        id: pw
        property string network: ""
        property var answer: null
        title: "Join “" + network + "”"
        subtitle: "This network needs a password."
        acceptText: "Join"
        acceptEnabled: pwField.text.length > 0
        onAccepted: { const a = answer; close(); if (a) a(pwField.text); }
        onCancelled: Network._joining = null
        Field { id: pwField; width: parent.width; password: true; placeholder: "Password"; onAccepted: pw.accept() }
    }

    // A network by hand: hidden, or one that needs a sign-in (WPA Enterprise).
    Sheet {
        id: join
        property bool hidden: false
        property string security: "wpa"
        property string method: "peap"
        property string phase2: "mschapv2"
        function openFor(ssid, hid, enterprise) {
            hidden = hid; security = enterprise ? "eap" : "wpa"; method = "peap"; phase2 = "mschapv2";
            ssidField.text = ssid; passField.text = ""; idField.text = ""; anonField.text = ""; domainField.text = ""; caField.text = "";
            open();
            if (ssid) (enterprise ? idField : passField).takeFocus(); else ssidField.takeFocus();
        }
        title: hidden ? "Join a hidden network" : ssidField.text ? "Join “" + ssidField.text + "”" : "Join a network"
        subtitle: security === "eap" ? "Networks at work or university ask for a user name and password (and often a certificate from your admin)." : ""
        acceptText: "Join"
        acceptEnabled: ssidField.text.trim().length > 0 && (security === "none" || passField.text.length > 0 || security === "eap") && (security !== "eap" || idField.text.trim().length > 0)
        onAccepted: {
            const req = { ssid: ssidField.text.trim(), hidden: hidden, security: security, password: passField.text };
            if (security === "eap") req.eap = { method: method, phase2: phase2, identity: idField.text.trim(), anonymous: anonField.text.trim(),
                                                domain: domainField.text.trim(), ca: caField.text.trim() };
            busy = true;
            page.run(["wifi-add"], (ok, err, out) => {
                join.busy = false;
                if (!ok) { join.error = err || "That did not work."; return; }
                let r = {};
                try { r = JSON.parse(out); } catch (e) {}
                if (r.connected) join.close();
                else join.error = "Saved, but not connected: " + (r.message || "the network did not answer") + ".";
            }, JSON.stringify(req));
        }
        Label { text: "Network name"; role: "dim"; size: Tokens.textSmall }
        Field { id: ssidField; width: parent.width; placeholder: "SSID" }
        Label { text: "Security"; role: "dim"; size: Tokens.textSmall }
        Choice {
            options: [{ v: "none", t: "None" }, { v: "wpa", t: "WPA2 Personal" }, { v: "sae", t: "WPA3 Personal" }, { v: "eap", t: "Enterprise" }]
            current: join.security; onPicked: v => join.security = v
        }
        Column {
            visible: join.security === "eap"
            width: parent.width; spacing: Tokens.gap
            Label { text: "Sign-in method"; role: "dim"; size: Tokens.textSmall }
            Choice { options: [{ v: "peap", t: "PEAP" }, { v: "ttls", t: "TTLS" }, { v: "pwd", t: "PWD" }]; current: join.method; onPicked: v => join.method = v }
            Label { visible: join.method !== "pwd"; text: "Inner method"; role: "dim"; size: Tokens.textSmall }
            Choice { visible: join.method !== "pwd"; options: [{ v: "mschapv2", t: "MSCHAPv2" }, { v: "pap", t: "PAP" }, { v: "gtc", t: "GTC" }]; current: join.phase2; onPicked: v => join.phase2 = v }
            Field { id: idField; width: parent.width; placeholder: "User name" }
            Field { id: anonField; visible: join.method !== "pwd"; width: parent.width; placeholder: "Anonymous identity (optional)" }
            Field { id: domainField; visible: join.method !== "pwd"; width: parent.width; placeholder: "Server domain, e.g. radius.example.org (optional)" }
            Row {
                visible: join.method !== "pwd"
                width: parent.width; spacing: Tokens.gap
                Field { id: caField; width: parent.width - caBtn.width - Tokens.gap; placeholder: "CA certificate (optional)" }
                Capsule { id: caBtn; label: "Choose…"; anchors.verticalCenter: parent.verticalCenter; onClicked: caFile.open() }
            }
        }
        Field { id: passField; visible: join.security !== "none"; width: parent.width; password: true; placeholder: "Password"; onAccepted: join.accept() }
    }
    FileDialog {
        id: caFile
        title: "CA certificate"
        nameFilters: ["Certificates (*.pem *.crt *.cer *.der)", "All files (*)"]
        onAccepted: caField.text = decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""))
    }
    // A connection's addressing: automatic or fixed, DNS, IPv6; join it on its own; metered.
    Sheet {
        id: details
        property var conn: null
        property string method: "auto"
        property string ipv6: "auto"
        property string metered: "unknown"
        property bool autoconnect: true
        function openFor(c) {
            conn = c; open();
            page.run(["show", c.uuid], (ok, err, out) => {
                let s = null;
                try { s = JSON.parse(out); } catch (e) {}
                if (!ok || !s) { details.error = err || "Could not read this connection."; return; }
                details.method = s.method; details.ipv6 = s.ipv6; details.metered = s.metered; details.autoconnect = s.autoconnect;
                addrField.text = s.address; gwField.text = s.gateway; dnsField.text = s.dns;
            });
        }
        title: conn ? conn.name : ""
        subtitle: conn && conn.kind === "ethernet" ? "Wired connection" + (conn.device ? " · " + conn.device : "") : "Wi-Fi network"
        acceptText: "Save"
        acceptEnabled: details.method === "auto" || addrField.text.trim().length > 0
        onAccepted: {
            const args = ["set", conn.uuid, "method=" + method, "dns=" + dnsField.text.trim(), "ipv6=" + ipv6,
                          "autoconnect=" + (autoconnect ? "yes" : "no"), "metered=" + metered];
            if (method === "manual") args.push("address=" + addrField.text.trim(), "gateway=" + gwField.text.trim());
            busy = true;
            page.run(args, (ok, err) => { details.busy = false; if (ok) details.close(); else details.error = err || "That did not work."; });
        }
        Label { text: "IPv4"; role: "dim"; size: Tokens.textSmall }
        Choice { options: [{ v: "auto", t: "Automatic (DHCP)" }, { v: "manual", t: "Manual" }]; current: details.method; onPicked: v => details.method = v }
        Field { id: addrField; visible: details.method === "manual"; width: parent.width; mono: true; placeholder: "Address, e.g. 192.168.1.20/24" }
        Field { id: gwField; visible: details.method === "manual"; width: parent.width; mono: true; placeholder: "Gateway, e.g. 192.168.1.1" }
        Label { text: "DNS servers"; role: "dim"; size: Tokens.textSmall }
        Field { id: dnsField; width: parent.width; mono: true; placeholder: "Automatic — or e.g. 1.1.1.1 9.9.9.9" }
        Label { text: "IPv6"; role: "dim"; size: Tokens.textSmall }
        Choice { options: [{ v: "auto", t: "Automatic" }, { v: "disabled", t: "Off" }]; current: details.ipv6; onPicked: v => details.ipv6 = v }
        Label { text: "Metered (apps go easy on data)"; role: "dim"; size: Tokens.textSmall }
        Choice { options: [{ v: "unknown", t: "Automatic" }, { v: "yes", t: "Yes" }, { v: "no", t: "No" }]; current: details.metered; onPicked: v => details.metered = v }
        Row {
            width: parent.width; spacing: Tokens.gap
            Label { text: "Connect automatically"; width: parent.width - autoToggle.width - Tokens.gap; anchors.verticalCenter: parent.verticalCenter }
            Toggle { id: autoToggle; checked: details.autoconnect; onToggled: details.autoconnect = !details.autoconnect }
        }
        Capsule {
            visible: !!details.conn && details.conn.kind === "wifi"
            icon: "trash"; label: "Forget this network"
            onClicked: { const c = details.conn; details.close(); page.run(["delete", c.uuid]); }
        }
    }
    Sheet {
        id: remove
        property var conn: null
        function ask(c) { conn = c; open(); }
        title: "Remove “" + (conn ? conn.name : "") + "”?"
        subtitle: "The profile is deleted; importing it again brings it back."
        acceptText: "Remove"
        danger: true
        onAccepted: { const c = conn; close(); page.run(["delete", c.uuid]); }
    }

    // One of a few, as chips; the chosen one in the accent.
    component Choice: Flow {
        id: choice
        property var options: []
        property string current: ""
        signal picked(string v)
        width: parent ? parent.width : 400
        spacing: 4
        Repeater {
            model: choice.options
            delegate: Rectangle {
                required property var modelData
                readonly property bool on: modelData.v === choice.current
                height: Tokens.islandHeight * 1.05; radius: height / 2
                width: ct.implicitWidth + Tokens.padding * 1.4
                color: on ? Colors.accent : Colors.alpha(Colors.text, cm.containsMouse ? 0.1 : 0.05)
                Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
                Label { id: ct; anchors.centerIn: parent; text: modelData.t; role: parent.on ? "onAccent" : "text"; size: Tokens.textSmall + 1 }
                MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: choice.picked(modelData.v) }
            }
        }
    }
}
