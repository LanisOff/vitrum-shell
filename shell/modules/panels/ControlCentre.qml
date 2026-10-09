import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components

/*
 * Control Centre: a fixed two-column grid of chips, volume and brightness,
 * and the media card. Wi-Fi and Bluetooth chips expand into their lists
 * inside the panel (the sheet's height springs with the content).
 */
Column {
    id: root
    spacing: Tokens.gap
    readonly property real col: Tokens.islandHeight * 6
    width: col * 2 + Tokens.gap
    property string expanded: ""        // "" | "wifi" | "bluetooth" | "awake" | "sound" | "phone"

    Grid {
        columns: 2
        spacing: Tokens.gap
        Chip {
            width: root.col
            icon: Network.kind === "wired" ? "ethernet" : Network.wifiEnabled ? "wifi" : "wifi-off"
            title: Network.kind === "wired" ? "Ethernet" : "Wi-Fi"
            subtitle: Network.online ? Network.name : Network.nm ? (Network.wifiEnabled ? "Not connected" : "Off") : "Offline"
            active: Network.online
            hasMenu: Network.nm
            onToggled: if (Network.nm) Network.setWifiEnabled(!Network.wifiEnabled)
            onExpand: root.expanded = root.expanded === "wifi" ? "" : "wifi"
        }
        Chip {
            width: root.col
            visible: Bluetooth.present
            icon: Bluetooth.powered ? "bluetooth" : "bluetooth-off"
            title: "Bluetooth"
            subtitle: !Bluetooth.powered ? "Off" : Bluetooth.connected.length ? Bluetooth.connected.map(d => d.name).join(", ") : "On"
            active: Bluetooth.powered
            hasMenu: Bluetooth.powered
            onToggled: Bluetooth.setPowered(!Bluetooth.powered)
            onExpand: { root.expanded = root.expanded === "bluetooth" ? "" : "bluetooth"; Bluetooth.scan(root.expanded === "bluetooth"); }
        }
        Chip {
            width: root.col
            visible: Vpn.available
            icon: "vpn"; title: "VPN"
            Component.onCompleted: if (!Vpn.throneItem) Vpn.listWg()
            subtitle: Vpn.active ? Vpn.label : Vpn.throneItem ? "Throne · off" : "Off"
            active: Vpn.active
            onToggled: Vpn.toggle()
        }
        Chip {
            width: root.col
            visible: Phone.devices.length > 0
            icon: "phone"; title: Phone.phone ? Phone.phone.name : "Phone"
            subtitle: !Phone.connected ? "Not in reach" : Phone.phone.charge >= 0 ? Phone.phone.charge + "%" + (Phone.phone.charging ? " · charging" : "") : "Connected"
            active: Phone.connected
            hasMenu: Phone.connected
            onToggled: if (Phone.connected) root.expanded = root.expanded === "phone" ? "" : "phone"; else Phone.settings()
            onExpand: root.expanded = root.expanded === "phone" ? "" : "phone"
        }
        Chip {
            width: root.col
            icon: "dnd"; title: "Do not disturb"; subtitle: Notifs.doNotDisturb ? "On" : "Off"
            active: Notifs.doNotDisturb
            onToggled: Notifs.setDoNotDisturb(!Notifs.doNotDisturb)
        }
        Chip {
            width: root.col
            icon: Colors.dark ? "dark" : "light"
            title: "Appearance"
            subtitle: ({ auto: "Automatic", light: "Light", dark: "Dark" })[Settings.get("scheme.mode", "auto")]
            active: Settings.get("scheme.mode", "auto") !== "auto"
            onToggled: Settings.set("scheme.mode", ({ auto: "light", light: "dark", dark: "auto" })[Settings.get("scheme.mode", "auto")])
        }
        Chip {
            width: root.col
            visible: Power.profiles.length > 0
            icon: Power.profile === "performance" ? "profile-performance" : Power.profile === "power-saver" ? "profile-saver" : "profile-balanced"
            title: "Power mode"
            subtitle: ({ "performance": "Performance", "balanced": "Balanced", "power-saver": "Saver" })[Power.profile] || Power.profile
            active: Power.profile !== "balanced"
            onToggled: {
                const order = ["balanced", "performance", "power-saver"].filter(p => Power.profiles.indexOf(p) >= 0);
                Power.setProfile(order[(order.indexOf(Power.profile) + 1) % order.length]);
            }
        }
        Chip {
            width: root.col
            icon: "coffee"; title: "Stay awake"
            subtitle: Awake.mode === "on" ? "Until turned off"
                    : Awake.mode === "timed" ? "Until " + Qt.formatTime(new Date(Awake.until), Settings.get("clock.h24", true) ? "HH:mm" : "h:mm ap")
                    : Awake.automatic || Awake.media ? "On while something plays" : "Off"
            active: Awake.active
            hasMenu: true
            onToggled: Awake.toggle()
            onExpand: root.expanded = root.expanded === "awake" ? "" : "awake"
        }
        Chip {
            width: root.col
            icon: "gamepad"; title: "Game mode"
            subtitle: GameMode.forced ? "On" : GameMode.active ? (GameMode.game ? GameMode.game.title || "A game" : "On") : "Automatic"
            active: GameMode.active
            onToggled: GameMode.forced = !GameMode.forced
        }
        Chip {
            width: root.col
            icon: "recording"; title: "Record screen"; subtitle: UiState.recording ? "Recording" : "Off"
            active: UiState.recording
            onToggled: { UiState.closePanel(); if (UiState.recording) UiState.stopRecording(); else Capture.open({ kind: "video" }); }
        }
    }

    // Expanded lists
    Card {
        visible: root.expanded === "wifi"
        width: parent.width
        Column {
            width: root.width - 2 * Tokens.padding
            spacing: 2
            Repeater {
                model: root.expanded === "wifi" ? Network.wifiNetworks.slice(0, 8) : []
                Capsule {
                    required property var modelData
                    width: parent.width
                    icon: "wifi"; label: modelData.name + (modelData.connected ? "  ·  connected" : "")
                    active: modelData.connected
                    onClicked: if (!modelData.connected) Network.connect(modelData)
                }
            }
            Label { visible: Network.wifiNetworks.length === 0; text: "No networks"; role: "dim" }
        }
    }
    Card {
        visible: root.expanded === "bluetooth"
        width: parent.width
        Column {
            width: root.width - 2 * Tokens.padding
            spacing: 2
            Repeater {
                model: root.expanded === "bluetooth" ? Bluetooth.devices.filter(d => d.paired || d.name).slice(0, 8) : []
                Capsule {
                    required property var modelData
                    width: parent.width
                    icon: modelData.connected ? "bluetooth-connected" : "bluetooth"
                    label: (modelData.name || modelData.address) + (modelData.batteryAvailable ? "  ·  " + Math.round(modelData.battery * 100) + "%" : "")
                    active: modelData.connected
                    onClicked: Bluetooth.toggle(modelData)
                }
            }
            Label { visible: Bluetooth.devices.length === 0; text: Bluetooth.discovering ? "Searching…" : "No devices"; role: "dim" }
        }
    }

    Card {
        visible: root.expanded === "phone" && Phone.connected
        width: parent.width
        Flow {
            width: root.width - 2 * Tokens.padding
            spacing: Tokens.gap / 2
            Capsule { icon: "notifications"; label: "Ring it"; onClicked: Phone.ring() }
            Capsule { icon: "folder"; label: "Its files"; onClicked: { UiState.closePanel(); Phone.browse(); } }
            Capsule { icon: "clipboard"; label: "Send the clipboard"; onClicked: clipSend.running = true }
            Capsule { icon: "settings"; label: "KDE Connect"; onClicked: { UiState.closePanel(); Phone.settings(); } }
        }
    }
    // The clipboard to the phone (a link is sent as a link, text as text).
    Process { id: clipSend; command: ["sh", "-c", 't=$(wl-paste --no-newline 2>/dev/null) && [ -n "$t" ] && exec vitrum-phone share "$1" "$t"', "_", Phone.phone ? Phone.phone.id : ""] }
    Card {
        visible: root.expanded === "awake"
        width: parent.width
        Column {
            width: root.width - 2 * Tokens.padding
            spacing: 2
            Repeater {
                model: [{ label: "Until turned off", on: () => Awake.setOn(), active: () => Awake.mode === "on" },
                        { label: "For 1 hour", on: () => Awake.setFor(60), active: () => false },
                        { label: "For 2 hours", on: () => Awake.setFor(120), active: () => false },
                        { label: "Off", on: () => Awake.setOff(), active: () => !Awake.manual }]
                Capsule {
                    required property var modelData
                    width: parent.width
                    icon: "coffee"; label: modelData.label
                    active: modelData.active()
                    onClicked: { modelData.on(); root.expanded = ""; }
                }
            }
            Label { visible: Awake.automatic || Awake.media; text: Awake.media ? "On by itself while something plays" : "On by itself while a fullscreen video or game runs"; role: "dim"; size: Tokens.textSmall }
        }
    }

    Row {
        visible: Audio.available
        spacing: Tokens.gap
        Slider {
            width: root.width - mixerButton.width - Tokens.gap
            icon: Audio.muted ? "volume-mute" : "volume-high"
            value: Audio.volume
            onMoved: v => Audio.setVolume(v)
        }
        Capsule { id: mixerButton; icon: "mixer"; active: root.expanded === "sound"; onClicked: root.expanded = root.expanded === "sound" ? "" : "sound" }
    }
    // Where sound goes, what plays how loud, which microphone (and its noise filter).
    Card {
        visible: root.expanded === "sound"
        width: parent.width
        Column {
            width: root.width - 2 * Tokens.padding
            spacing: Tokens.gap
            Label { text: "Output"; role: "dim"; size: Tokens.textSmall }
            Flow {
                width: parent.width; spacing: Tokens.gap / 2
                Repeater {
                    model: root.expanded === "sound" ? Audio.sinks : []
                    Capsule {
                        required property var modelData
                        icon: /headphone|headset/i.test(modelData.description || "") ? "headphones" : "speaker"
                        label: modelData.description || modelData.nickname || modelData.name
                        active: modelData === Audio.sink
                        onClicked: Audio.setDefaultSink(modelData)
                    }
                }
            }
            Label { text: "Apps"; role: "dim"; size: Tokens.textSmall; visible: Audio.streams.length > 0 }
            Repeater {
                model: root.expanded === "sound" ? Audio.streams : []
                Row {
                    required property var modelData
                    spacing: Tokens.gap
                    Label { width: root.width * 0.3; text: Audio.streamName(modelData); elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                    Slider {
                        width: root.width - 2 * Tokens.padding - root.width * 0.3 - Tokens.gap
                        icon: modelData.audio && modelData.audio.muted ? "volume-mute" : "volume-low"
                        value: modelData.audio ? modelData.audio.volume : 0
                        onMoved: v => Audio.setStreamVolume(modelData, v)
                    }
                }
            }
            Label { text: "Microphone"; role: "dim"; size: Tokens.textSmall; visible: Audio.sources.length > 0 }
            Flow {
                width: parent.width; spacing: Tokens.gap / 2
                Repeater {
                    model: root.expanded === "sound" ? Audio.sources.filter(n => n.name !== NoiseFilter.nodeName) : []
                    Capsule {
                        required property var modelData
                        icon: "mic"
                        label: modelData.description || modelData.nickname || modelData.name
                        active: modelData === Audio.source || (NoiseFilter.on && NoiseFilter.previous === modelData.name)
                        onClicked: Audio.setDefaultSource(modelData)
                    }
                }
            }
            Row {
                visible: NoiseFilter.available
                spacing: Tokens.gap
                Toggle { checked: NoiseFilter.on; onToggled: NoiseFilter.toggle(); anchors.verticalCenter: parent.verticalCenter }
                Label { text: "Noise filter for the microphone"; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
    Slider {
        width: parent.width
        visible: Power.hasBacklight
        icon: "brightness"
        value: Power.brightness
        onMoved: v => Power.setBrightness(v)
    }

    Card {
        visible: Media.available
        width: parent.width
        Row {
            spacing: Tokens.gap
            Icon { name: "music"; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
            Label { text: Media.title + (Media.artist ? " — " + Media.artist : ""); width: root.width - 2 * Tokens.padding - Tokens.iconSize * 5; anchors.verticalCenter: parent.verticalCenter }
            Icon { name: Media.playing ? "pause" : "play"; anchors.verticalCenter: parent.verticalCenter; MouseArea { anchors.fill: parent; onClicked: Media.playPause() } }
            Icon { name: "next"; anchors.verticalCenter: parent.verticalCenter; MouseArea { anchors.fill: parent; onClicked: Media.next() } }
        }
    }
}
