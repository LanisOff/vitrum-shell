pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth as BT

/*
 * Bluetooth through Quickshell.Bluetooth (BlueZ over D-Bus), and — in the
 * shell only — the pairing agent: tools/vitrum-bt-agent asks its questions
 * (a code to compare, a PIN to type) and the answers come from Prompt dialogs.
 */
Singleton {
    id: root
    readonly property var adapter: BT.Bluetooth.defaultAdapter
    readonly property bool present: adapter !== null
    readonly property bool powered: present && adapter.enabled
    readonly property bool discovering: present && adapter.discovering
    readonly property bool discoverable: present && adapter.discoverable
    readonly property var devices: present ? adapter.devices.values : []
    readonly property var connected: devices.filter(d => d.connected)
    // Settings: what is yours, and what is around (named devices only — a
    // bare address is someone's watch three flats away).
    readonly property var paired: devices.filter(d => d.paired).sort(_byName)
    readonly property var nearby: devices.filter(d => !d.paired && d.deviceName).sort(_byName)
    function _byName(a, b) { return (b.connected - a.connected) || String(a.name).localeCompare(String(b.name)); }

    function setPowered(on) { if (present) adapter.enabled = on; }
    function scan(on) { if (present && powered) adapter.discovering = on; }
    function setDiscoverable(on) { if (present) adapter.discoverable = on; }
    // Connecting to a device not paired yet pairs it first (and connects once paired).
    function toggle(device) {
        if (!device) return;
        if (device.connected) device.disconnect();
        else if (!device.paired) pair(device);
        else device.connect();
    }
    property var _connectAfterPair: []
    function pair(device) {
        if (!device || device.paired || device.pairing) return;
        _connectAfterPair = _connectAfterPair.concat([device.address]);
        device.pair();
    }
    function forget(device) { if (device) device.forget(); }
    // Paired: connect, as asked. (The agent marks it trusted.) The model stays
    // the device list: emptying the waiting list must not destroy the handler running.
    Instantiator {
        model: root.devices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onPairedChanged() {
                const d = modelData;
                if (!d.paired || root._connectAfterPair.indexOf(d.address) < 0) return;
                d.connect();
                root._connectAfterPair = root._connectAfterPair.filter(a => a !== d.address);
            }
            function onPairingChanged() {
                // Gave up without pairing: stop waiting for it.
                const d = modelData;
                if (!d.pairing && !d.paired) root._connectAfterPair = root._connectAfterPair.filter(a => a !== d.address);
            }
        }
    }

    // ------------------------------------------------------------ agent ---
    readonly property bool inShell: !Quickshell.env("VITRUM_NO_THEME")
    property var _asked: ({})          // agent question id → Prompt token

    Process {
        id: agent
        running: root.inShell && root.present
        command: ["vitrum-bt-agent"]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => { try { root._question(JSON.parse(line)); } catch (e) { console.warn("bt-agent:", line); } }
        }
        stderr: SplitParser { onRead: line => console.warn("bt-agent:", line) }
        // Crashed or killed: back after a pause, while there is an adapter —
        // a longer one each time it dies at once (not installed, no D-Bus).
        onStarted: root._agentStarted = Date.now()
        onExited: {
            if (!root.inShell || !root.present) return;
            root._agentDelay = Date.now() - root._agentStarted < 10000 ? Math.min(root._agentDelay * 2, 300000) : 5000;
            again.interval = root._agentDelay;
            again.restart();
        }
    }
    property real _agentStarted: 0
    property int _agentDelay: 5000
    Timer { id: again; interval: 5000; onTriggered: agent.running = root.inShell && root.present }

    function _reply(id, ok, value) { agent.write(JSON.stringify({ id: id, ok: ok, value: value || "" }) + "\n"); }
    function _question(m) {
        if (m.type === "ready" || m.type === "error") { if (m.type === "error") console.warn("bt-agent:", m.message); return; }
        if (m.type === "cancel") {
            const t = _asked[m.id];
            if (t !== undefined) { Prompt.dismiss(t); delete _asked[m.id]; }
            return;
        }
        const who = m.name || m.address || "A device";
        const q = { icon: "bluetooth" };
        switch (m.type) {
        case "confirm":
            Object.assign(q, { title: "Pair with " + who + "?", message: "Make sure this code is the same on " + who + ".", code: m.passkey, okText: "Pair" });
            break;
        case "pin":
            Object.assign(q, { title: "Pair with " + who, message: "Type the PIN shown on " + who + " (often 0000 or 1234).", field: "text", placeholder: "PIN", okText: "Pair" });
            break;
        case "passkey":
            Object.assign(q, { title: "Pair with " + who, message: "Type the six-digit code shown on " + who + ".", field: "number", placeholder: "Code", okText: "Pair" });
            break;
        case "display-pin":
        case "display-passkey":
            Object.assign(q, { title: "Pair with " + who, message: "Type this code on " + who + ", then press Enter there.", code: m.passkey, info: true, okText: "Hide" });
            break;
        case "authorize":
            Object.assign(q, { title: who + " wants to pair", message: "Allow it to pair with this computer?", okText: "Allow", cancelText: "Deny" });
            break;
        case "service":
            Object.assign(q, { title: who + " wants to connect", message: "Allow it to use " + (m.service || "a service") + "?", okText: "Allow", cancelText: "Deny" });
            break;
        default:
            return;
        }
        const display = m.type.indexOf("display-") === 0;
        _asked[m.id] = Prompt.ask(q, (ok, value) => { delete root._asked[m.id]; if (!display) root._reply(m.id, ok, value); });
    }
}
