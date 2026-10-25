import QtQuick
import qs.services
import qs.theme
import qs.components

/*
 * The batteries of what is connected: Bluetooth devices that report one
 * (Bluetooth), and the phone through KDE Connect (Phone).
 *   S   the emptiest as a ring, its name under it
 *   M   the header; a row each — the kind of device, its name, a small bar
 *       and the percentage — as many as fit
 *   L   the same, with room for more
 * A bar turns red at 20 % and below.
 * options: bluetooth, phone (which to include).
 * In a gallery card with nothing connected, sample devices stand in.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    // BlueZ names a kind with a freedesktop icon name (audio-headset, input-mouse…).
    function glyph(kind) {
        const k = String(kind || "");
        if (/head(set|phone)|earbud/i.test(k)) return "headphones";
        if (/mouse/i.test(k)) return "mouse";
        if (/keyboard/i.test(k)) return "keyboard";
        if (/phone|tablet/i.test(k)) return "phone";
        if (/gaming|joystick|gamepad/i.test(k)) return "gamepad";
        if (/audio|speaker/i.test(k)) return "speaker";
        return "bluetooth";
    }

    readonly property var found: {
        const out = [];
        if (options.bluetooth !== false)
            for (const d of Bluetooth.connected)
                if (d.batteryAvailable)
                    out.push({ icon: glyph(d.icon), name: d.name || d.deviceName || d.address, level: d.battery, charging: false });
        if (options.phone !== false)
            for (const p of Phone.devices)
                if (p.reachable && p.charge >= 0)
                    out.push({ icon: "phone", name: p.name, level: p.charge / 100, charging: !!p.charging });
        return out;
    }
    readonly property bool sample: preview && found.length === 0
    readonly property var devices: sample ? [
        { icon: "headphones", name: "WH-1000XM5", level: 0.72, charging: false },
        { icon: "phone", name: "Pixel 9", level: 0.48, charging: true },
        { icon: "mouse", name: "MX Master 3S", level: 0.16, charging: false }
    ] : found
    readonly property var lowest: devices.length ? devices.reduce((a, b) => b.level < a.level ? b : a) : null
    function tint(d) { return d && d.level <= 0.2 && !d.charging ? Colors.danger : Colors.accent; }
    function pct(d) { return d ? Math.round(d.level * 100) + "%" : ""; }

    WidgetHeader {
        id: head
        visible: root.sizeClass !== "S"
        height: visible ? implicitHeight : 0
        icon: "devices"; title: "Devices"
        trailing: root.devices.length > 1 ? String(root.devices.length) : ""
    }
    WidgetEmpty {
        visible: root.devices.length === 0
        icon: "devices"
        text: "No devices with a battery"
    }

    // ---- S: the one to charge first.
    Column {
        visible: root.sizeClass === "S" && root.lowest !== null
        anchors.centerIn: parent
        spacing: Tokens.gap * 0.5
        Meter {
            group: "widgets"
            anchors.horizontalCenter: parent.horizontalCenter
            kind: "circular"
            width: Math.min(root.width, root.height) * 0.62; height: width
            value: root.lowest ? root.lowest.level : 0
            trailing: root.pct(root.lowest)
            color: root.tint(root.lowest)
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            Icon { name: root.lowest ? root.lowest.icon : "bluetooth"; size: Tokens.textSmall + 3; color: Colors.textDim; anchors.verticalCenter: parent.verticalCenter }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, root.width - Tokens.textSmall - 8)
                text: root.lowest ? root.lowest.name : ""
                role: "dim"; size: Tokens.textSmall
            }
        }
    }

    // ---- M and L: a row each.
    Column {
        id: rows
        visible: root.sizeClass !== "S"
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: Tokens.gap * 0.6; bottom: parent.bottom }
        readonly property real rowH: Math.round(Tokens.textSize * 2.2)
        readonly property int fits: Math.max(1, Math.floor((height + 2) / (rowH + 2)))
        spacing: 2
        Repeater {
            model: root.devices.slice(0, rows.fits)
            delegate: Item {
                required property var modelData
                width: rows.width; height: rows.rowH
                // The kind of device: a plain line icon in accent2, as in the header.
                Item {
                    id: lead
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(parent.height * 0.82); height: width
                    Icon { anchors.centerIn: parent; name: modelData.icon; size: Math.round(parent.width * 0.72); color: Colors.accent2 }
                }
                Label {
                    anchors { left: lead.right; leftMargin: Tokens.gap * 0.8; right: bar.left; rightMargin: Tokens.gap; verticalCenter: parent.verticalCenter }
                    text: modelData.name
                    font.weight: Font.Medium
                }
                Meter {
                    id: bar
                    group: "widgets"
                    anchors { right: pctBox.left; rightMargin: Tokens.gap * 0.8; verticalCenter: parent.verticalCenter }
                    width: Math.round(rows.width * 0.26)
                    thickness: 4
                    value: modelData.level
                    color: root.tint(modelData)
                }
                Row {
                    id: pctBox
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: Math.round(Tokens.textSmall * 3.6)
                    layoutDirection: Qt.RightToLeft
                    spacing: 2
                    Label { text: root.pct(modelData); numeric: true; size: Tokens.textSmall; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                    Icon { visible: modelData.charging; name: "battery"; size: Tokens.textSmall + 1; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
}
