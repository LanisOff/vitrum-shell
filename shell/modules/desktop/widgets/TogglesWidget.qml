import QtQuick
import qs.services
import qs.theme
import qs.components

/*
 * The Control Centre's switches as tiles: Wi-Fi, Bluetooth, Do not disturb,
 * Stay awake. A tap flips one, as the Control Centre's does.
 *   S   two by two, the icons alone
 *   M   the header; two by two with the name and the state (one row of
 *       them when there are three or fewer)
 * A tile that is on is filled with the accent's tone.
 * options: wifi, bluetooth, dnd, awake (which tiles).
 * In a gallery card the tiles show the real states and take no clicks.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    readonly property var tiles: ["wifi", "bluetooth", "dnd", "awake"].filter(k => options[k] !== false)
    readonly property int n: tiles.length
    readonly property bool small: sizeClass === "S"
    readonly property int cols: n <= 1 ? 1 : small || n === 4 ? 2 : n
    readonly property int rowCount: Math.max(1, Math.ceil(n / cols))

    // Per tile: what it shows and what a tap does (the Control Centre's calls).
    function available(k) {
        return k === "wifi" ? Network.nm : k === "bluetooth" ? Bluetooth.present : true;
    }
    function isOn(k) {
        switch (k) {
        case "wifi": return Network.wifiEnabled;
        case "bluetooth": return Bluetooth.powered;
        case "dnd": return Notifs.doNotDisturb;
        case "awake": return Awake.active;
        }
        return false;
    }
    function glyph(k) {
        switch (k) {
        case "wifi": return Network.wifiEnabled ? "wifi" : "wifi-off";
        case "bluetooth": return Bluetooth.powered ? "bluetooth" : "bluetooth-off";
        case "dnd": return "dnd";
        case "awake": return "coffee";
        }
        return "help";
    }
    function title(k) {
        return { wifi: "Wi-Fi", bluetooth: "Bluetooth", dnd: "Do not disturb", awake: "Stay awake" }[k] || k;
    }
    function status(k) {
        if (!available(k)) return "Unavailable";
        switch (k) {
        case "wifi": return Network.kind === "wifi" ? Network.name : Network.wifiEnabled ? "On" : "Off";
        case "bluetooth": return !Bluetooth.powered ? "Off" : Bluetooth.connected.length ? Bluetooth.connected.map(d => d.name).join(", ") : "On";
        case "awake": return Awake.manual ? "On" : Awake.active ? "While playing" : "Off";
        }
        return isOn(k) ? "On" : "Off";
    }
    function flip(k) {
        switch (k) {
        case "wifi": Network.setWifiEnabled(!Network.wifiEnabled); break;
        case "bluetooth": Bluetooth.setPowered(!Bluetooth.powered); break;
        case "dnd": Notifs.setDoNotDisturb(!Notifs.doNotDisturb); break;
        case "awake": Awake.toggle(); break;
        }
    }

    WidgetHeader {
        id: head
        visible: !root.small
        height: visible ? implicitHeight : 0
        icon: "toggles"; title: "Quick toggles"
    }
    WidgetEmpty {
        visible: root.n === 0
        icon: "toggles"
        text: "No toggles chosen"
    }

    Grid {
        id: grid
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: root.small ? 0 : Tokens.gap * 0.8; bottom: parent.bottom }
        columns: root.cols
        spacing: Tokens.gap
        readonly property real tileW: (width - (root.cols - 1) * spacing) / root.cols
        readonly property real tileH: (height - (root.rowCount - 1) * spacing) / root.rowCount
        Repeater {
            model: root.tiles
            delegate: Rectangle {
                id: tile
                required property string modelData
                readonly property bool active: root.isOn(modelData)
                readonly property bool usable: root.available(modelData)
                // Wide enough for the name beside the icon; else stacked, or (S) the icon alone.
                readonly property bool beside: width >= 128
                width: grid.tileW; height: grid.tileH
                radius: Math.min(height / 2, Tokens.radiusInner * 1.6)
                color: active ? Colors.alpha(Colors.accent, Colors.dark ? 0.32 : 0.22)
                          : Colors.alpha(Colors.text, tap.containsMouse && usable ? 0.11 : 0.07)
                opacity: usable ? 1 : 0.5
                scale: tap.pressed ? 0.96 : 1
                Behavior on color { enabled: Motion.enabled; ColorAnim {} }
                Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }

                Icon {
                    id: icon
                    name: root.glyph(tile.modelData)
                    filled: tile.active
                    color: tile.active ? Colors.accent : Colors.text
                    size: root.small ? Math.round(Math.min(tile.width, tile.height) * 0.42)
                                     : Math.round(Math.min(Tokens.iconSize * 1.5, tile.height * 0.42))
                    x: tile.beside ? Tokens.padding : (tile.width - width) / 2
                    y: tile.beside || root.small ? (tile.height - height) / 2
                                                 : (tile.height - height - (root.small ? 0 : Tokens.textSmall + 6)) / 2
                }
                Column {
                    visible: !root.small
                    anchors {
                        left: tile.beside ? icon.right : parent.left
                        leftMargin: tile.beside ? Tokens.gap : 4
                        right: parent.right
                        rightMargin: tile.beside ? Tokens.gap : 4
                        top: tile.beside ? undefined : icon.bottom
                        topMargin: 4
                        verticalCenter: tile.beside ? parent.verticalCenter : undefined
                    }
                    Label {
                        width: parent.width
                        horizontalAlignment: tile.beside ? Text.AlignLeft : Text.AlignHCenter
                        text: root.title(tile.modelData)
                        size: Tokens.textSmall + 1; font.weight: Font.Medium
                    }
                    Label {
                        visible: tile.beside && tile.height >= Tokens.textSize * 3
                        width: parent.width
                        text: root.status(tile.modelData)
                        role: "dim"; size: Tokens.textSmall
                    }
                }
                MouseArea {
                    id: tap
                    anchors.fill: parent
                    enabled: !root.preview && tile.usable
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.flip(tile.modelData)
                }
            }
        }
    }
}
