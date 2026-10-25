import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import "../../../lib/netinfo.js" as Lib

/*
 * Where this machine is on the network: the Wi-Fi network or the wired
 * interface (Network), the local address it goes out from (`ip route get`),
 * the public address (asked of ipify.org, only if the options say so), and
 * the VPN (Vpn). A click on an address copies it.
 *   S   the network, the local address large, the VPN under it
 *   M   the header (the VPN at its end when on); a row each: the network,
 *       the local address, the public address, the VPN
 * options: publicIp (off; click: asked when its row is clicked; auto: asked
 * when it shows, when the network or the VPN changes, and every six hours).
 * The local address is read again when the network or the VPN changes, and
 * every five minutes while it shows, not under a game. In a gallery card,
 * sample addresses; nothing is read or asked.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    property bool started: false
    Component.onCompleted: Qt.callLater(() => { root.started = true; root.changed(); })
    readonly property bool live: started && !preview
    readonly property bool awake: live && !GameMode.active
    readonly property string publicMode: ["off", "click", "auto"].indexOf(options.publicIp) >= 0 ? options.publicIp : "click"

    property string localIp: ""
    property string publicIp: ""
    property string publicState: ""        // "" | asking | failed
    property string copied: ""             // the address just copied, for a moment

    // ---- what it shows, sample or live
    readonly property string kind: preview ? "wifi" : Network.kind
    readonly property string netName: preview ? "Home" : Network.name
    readonly property real strength: preview ? 0.8 : Network.strength
    readonly property string local: preview ? "192.168.1.24" : localIp
    readonly property string pub: preview ? "203.0.113.7" : publicIp
    readonly property bool vpnOn: preview ? false : Vpn.active
    readonly property string vpnText: vpnOn ? (Vpn.label || "On") : "Off"
    readonly property string netIcon: kind === "wired" ? "ethernet" : kind === "wifi"
        ? (strength >= 0.66 ? "wifi-high" : strength >= 0.33 ? "wifi-medium" : "wifi-low") : "network-off"
    readonly property string netTitle: kind === "wired" ? "Ethernet" : kind === "wifi" ? "Wi-Fi" : "Network"
    readonly property string netValue: kind === "none" ? "Offline" : netName
    readonly property string publicValue: pub ? pub : publicState === "asking" ? "Asking…" : publicState === "failed" ? "Try again" : "Show"

    // ------------------------------------------------------- reading ---
    Process {
        id: route
        command: ["sh", "-c", Lib.routeCommand()]
        stdout: StdioCollector { onStreamFinished: root.localIp = Lib.routeSrc(text).ip }
    }
    Process {
        id: lookup
        command: ["sh", "-c", Lib.publicCommand()]
        stdout: StdioCollector {
            onStreamFinished: {
                const ip = Lib.publicIp(text);
                root.publicIp = ip;
                root.publicState = ip ? "" : "failed";
            }
        }
        onExited: code => { if (code !== 0 && !root.publicIp) root.publicState = "failed"; }
    }
    function readLocal() { if (live && !route.running) route.running = true; }
    function askPublic() {
        if (!live || publicMode === "off" || lookup.running) return;
        publicState = "asking";
        lookup.running = true;
    }
    // The network or the VPN changed: the old public address is not this one.
    function changed() {
        if (!live) return;
        readLocal();
        if (publicMode === "auto") askPublic();
        else if (publicMode === "click" && publicIp) { publicIp = ""; publicState = ""; }
    }
    readonly property string netKey: [Network.kind, Network.name, Network.online, Vpn.active, Vpn.label].join("|")
    onNetKeyChanged: if (live) settle.restart()
    Timer { id: settle; interval: 2000; onTriggered: root.changed() }
    onPublicModeChanged: { publicIp = ""; publicState = ""; if (publicMode === "auto") askPublic(); }
    Timer { interval: 5 * 60 * 1000; repeat: true; running: root.awake; onTriggered: root.readLocal() }
    Timer { interval: 6 * 3600 * 1000; repeat: true; running: root.awake && root.publicMode === "auto"; onTriggered: root.askPublic() }

    function copy(text) {
        if (preview || !text) return;
        Quickshell.execDetached(["wl-copy", "--", text]);
        copied = text;
        copiedTimer.restart();
    }
    Timer { id: copiedTimer; interval: 1500; onTriggered: root.copied = "" }
    function clickPublic() {
        if (root.pub) root.copy(root.pub);
        else root.askPublic();
    }

    // -------------------------------------------------------- drawing ---
    WidgetHeader {
        id: head
        visible: root.sizeClass !== "S"
        height: visible ? implicitHeight : 0
        icon: "ip"; title: "Network"
        trailing: root.vpnOn ? "VPN on" : ""
    }

    // ---- S: one glance.
    Column {
        visible: root.sizeClass === "S"
        anchors.centerIn: parent
        width: root.width
        spacing: Math.round(Tokens.gap * 0.3)
        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: root.netIcon; size: Math.round(Tokens.iconSize * 1.6); color: Colors.accent2 }
        Label {
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: root.netValue
            font.weight: Font.Medium
        }
        Item {
            width: parent.width; height: sLocal.implicitHeight
            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width, sLocal.implicitWidth + Tokens.gap); height: parent.height
                radius: Tokens.radiusButton
                color: Colors.alpha(Colors.text, sTap.pressed ? 0.10 : sTap.containsMouse ? 0.06 : 0)
                Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
            }
            Label {
                id: sLocal
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width)
                text: root.copied && root.copied === root.local ? "Copied" : root.local || "No address"
                numeric: true
                size: Tokens.textSize + 1
                color: root.copied && root.copied === root.local ? Colors.accent : Colors.text
            }
            MouseArea { id: sTap; anchors.fill: parent; enabled: !root.preview && !!root.local; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.copy(root.local) }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            Icon { name: "vpn"; size: Tokens.textSmall + 2; color: root.vpnOn ? Colors.accent : Colors.textDim; anchors.verticalCenter: parent.verticalCenter }
            Label { text: root.vpnOn ? root.vpnText : "VPN off"; role: "dim"; size: Tokens.textSmall; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // ---- M: a row each.
    Column {
        id: rows
        visible: root.sizeClass !== "S"
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: Tokens.gap * 0.4; bottom: parent.bottom }
        // Keys, not values: the rows stay put (and keep the pointer) while their values change.
        readonly property var model: ["net", "local", "public", "vpn"].filter(k => k !== "public" || root.publicMode !== "off")
        readonly property real rowH: Math.min(Math.round(Tokens.textSize * 2), Math.floor(height / Math.max(1, model.length)))
        Repeater {
            model: rows.model
            delegate: Item {
                id: r
                required property string modelData
                readonly property var d: modelData === "net" ? { i: root.netIcon, t: root.netTitle, v: root.netValue }
                    : modelData === "local" ? { i: "ip", t: "Local IP", v: root.local || "No address", copy: root.local, act: "local" }
                    : modelData === "public" ? { i: "web", t: "Public IP", v: root.publicValue, copy: root.pub, act: "public" }
                    : { i: "vpn", t: "VPN", v: root.vpnText, lit: root.vpnOn }
                readonly property bool clickable: !!d.act && !root.preview && (d.act === "public" || !!d.copy)
                readonly property bool justCopied: !!d.copy && root.copied === d.copy
                width: rows.width; height: rows.rowH
                Rectangle {
                    anchors { fill: parent; leftMargin: -Tokens.gap * 0.4; rightMargin: -Tokens.gap * 0.4; topMargin: 1; bottomMargin: 1 }
                    radius: Tokens.radiusButton
                    color: Colors.alpha(Colors.text, !r.clickable ? 0 : tap.pressed ? 0.10 : tap.containsMouse ? 0.06 : 0)
                    Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
                }
                Icon {
                    id: ic
                    anchors.verticalCenter: parent.verticalCenter
                    name: r.d.i
                    size: Math.round(Math.min(Tokens.iconSize, rows.rowH * 0.8))
                    color: r.d.lit ? Colors.accent : Colors.accent2
                }
                Label {
                    anchors { left: ic.right; leftMargin: Tokens.gap * 0.6; verticalCenter: parent.verticalCenter }
                    width: parent.width * 0.38
                    text: r.d.t
                    role: "dim"; size: Tokens.textSmall + 1
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    // A copy glyph shows what a click does.
                    Icon {
                        visible: r.clickable && tap.containsMouse && !!r.d.copy && !r.justCopied
                        name: "copy"; size: Tokens.textSmall + 1; color: Colors.textDim
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        width: Math.min(implicitWidth, rows.width * 0.55)
                        horizontalAlignment: Text.AlignRight
                        text: r.justCopied ? "Copied" : r.d.v
                        numeric: true
                        size: Tokens.textSmall + 1; font.weight: Font.Medium
                        color: r.justCopied || r.d.lit ? Colors.accent
                             : r.d.act === "public" && !r.d.copy ? Colors.textDim : Colors.text
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: tap
                    anchors.fill: parent
                    enabled: r.clickable
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: r.d.act === "public" ? root.clickPublic() : root.copy(r.d.copy)
                }
            }
        }
    }
}
