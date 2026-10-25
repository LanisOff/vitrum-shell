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
 * Each is the Control Centre's glass tile; one that is on is tinted.
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
            delegate: Item {
                id: cell
                required property string modelData
                readonly property bool active: root.isOn(modelData)
                readonly property bool usable: root.available(modelData)
                // Wide enough for the name beside the icon: the Control Centre's
                // Tile. Else the same glass with the name under the icon, or (S)
                // the icon alone.
                readonly property bool beside: !root.small && width >= 128
                width: grid.tileW; height: grid.tileH
                opacity: usable ? 1 : 0.5

                Tile {
                    visible: cell.beside
                    enabled: cell.beside && cell.usable && !root.preview
                    anchors.fill: parent
                    group: "widgets"
                    icon: root.glyph(cell.modelData)
                    title: root.title(cell.modelData)
                    subtitle: cell.height >= Tokens.textSize * 3 ? root.status(cell.modelData) : ""
                    active: cell.active
                    onToggled: root.flip(cell.modelData)
                }

                Item {
                    id: stacked
                    visible: !cell.beside
                    anchors.fill: parent
                    scale: tap.pressed ? 0.97 : 1
                    Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
                    Surface {
                        anchors.fill: parent
                        group: "widgets"
                        level: 1
                        radius: Tokens.radiusTile
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.radiusTile
                        color: Colors.alpha(Colors.text, !cell.active && tap.containsMouse ? 0.06 : 0)
                        Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
                    }
                    ShellTint {
                        anchors.fill: parent
                        radius: Tokens.radiusTile
                        group: "widgets"
                        active: cell.active
                        hovered: tap.containsMouse
                    }
                    Icon {
                        id: icon
                        name: root.glyph(cell.modelData)
                        color: Colors.text
                        size: root.small ? Math.round(Math.min(stacked.width, stacked.height) * 0.42)
                                         : Math.round(Math.min(Tokens.iconSize * 1.5, stacked.height * 0.42))
                        x: (stacked.width - width) / 2
                        y: root.small ? (stacked.height - height) / 2
                                      : (stacked.height - height - Tokens.textSmall - 6) / 2
                    }
                    Label {
                        visible: !root.small
                        anchors { left: parent.left; right: parent.right; margins: 4; top: icon.bottom; topMargin: 4 }
                        horizontalAlignment: Text.AlignHCenter
                        text: root.title(cell.modelData)
                        size: Tokens.textSmall + 1; font.weight: Font.Medium
                    }
                    MouseArea {
                        id: tap
                        anchors.fill: parent
                        enabled: !cell.beside && cell.usable && !root.preview
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.flip(cell.modelData)
                    }
                }
            }
        }
    }
}
