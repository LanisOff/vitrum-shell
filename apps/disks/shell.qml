//@ pragma AppId vitrum-disks
//@ pragma Env VITRUM_NO_THEME=1
//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import qs.common
import qs.backend

/*
 * Disk Utility: drives and their volumes (lsblk), mount/unmount/eject through
 * udisks2, and — behind a typed confirmation, authenticated by polkit every
 * time — first aid, erase, partition table, rename, delete.
 *
 * The disk holding / or /boot is shown but never offered an action
 * (Disks.isProtected); the rule lives in the backend, not in these buttons.
 */
ShellRoot {
    id: app
    property var selected: null          // a disk or a partition object
    readonly property var disk: selected ? (selected.kind === "disk" ? selected : Disks.devices.find(d => d.name === selected.parent) || null) : null
    readonly property bool locked: Disks.isProtected(selected)
    // By name: a refresh hands over new objects for the same devices, which is
    // no reason to play the entrance again.
    readonly property string selectedName: selected ? selected.name : ""
    readonly property string diskName: disk ? disk.name : ""
    onSelectedNameChanged: if (detail) detail.enter()
    property string message: ""
    property bool messageOk: true

    Connections {
        target: Disks
        function onDevicesChanged() {
            // Keep the selection across refreshes (by name), else the first drive.
            const all = [].concat(...Disks.devices.map(d => [d].concat(d.partitions)));
            app.selected = (app.selected && all.find(x => x.name === app.selected.name)) || Disks.devices[0] || null;
        }
        function onOperationFinished(ok, msg) { app.message = msg; app.messageOk = ok; }
    }

    // qs ipc call disks select sda1 / sheet erase — for scripts and tests; the sheet still needs the typed name.
    IpcHandler {
        target: "disks"
        function select(name: string): void { const all = [].concat(...Disks.devices.map(d => [d].concat(d.partitions))); const f = all.find(x => x.name === name); if (f) app.selected = f; }
        function sheet(mode: string): void { if (!app.locked) sheet.open(mode); }
        function selected(): string { return app.selected ? app.selected.name : ""; }
    }

    AppWindow {
        appTitle: "Disk Utility"
        implicitWidth: 1000
        implicitHeight: 640
        titleRow: [
            Rectangle {
                height: Tokens.islandHeight * 0.9; width: height; radius: height / 2
                color: rm.containsMouse ? Colors.alpha(Colors.text, 0.12) : Colors.alpha(Colors.text, 0.06)
                Icon { anchors.centerIn: parent; name: "restart"; size: Tokens.iconSize * 0.9 }
                MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Disks.refresh() }
            }
        ]

        Row {
            anchors.fill: parent
            // ----------------------------------------------- drive list ---
            Flickable {
                id: side
                width: 280; height: parent.height
                contentHeight: list.implicitHeight + Tokens.padding * 2
                clip: true
                Column {
                    id: list
                    x: Tokens.padding; y: Tokens.padding
                    width: side.width - 2 * Tokens.padding
                    spacing: 2
                    Repeater {
                        model: [{ name: "Internal", ext: false }, { name: "External", ext: true }]
                        delegate: Column {
                            id: grp
                            required property var modelData
                            readonly property var disks: Disks.devices.filter(d => (d.removable || d.hotplug || d.transport === "usb") === modelData.ext)
                            visible: disks.length > 0
                            width: list.width
                            spacing: 2
                            Label { text: grp.modelData.name; role: "dim"; size: Tokens.textSmall; font.weight: Font.DemiBold; topPadding: Tokens.gap; leftPadding: Tokens.gap }
                            Repeater {
                                model: grp.disks
                                delegate: Column {
                                    id: dcol
                                    required property var modelData
                                    width: list.width
                                    spacing: 2
                                    Entry { item: dcol.modelData; depth: 0 }
                                    Repeater { model: dcol.modelData.partitions; delegate: Entry { required property var modelData; item: modelData; depth: modelData.kind === "volume" ? 2 : 1 } }
                                }
                            }
                        }
                    }
                    Label { visible: Disks.devices.length === 0; text: Disks.loading ? "Reading drives…" : "No drives found."; role: "dim"; leftPadding: Tokens.gap }
                }
            }
            Rectangle { width: 1; height: parent.height; color: Colors.alpha(Colors.text, 0.08) }
            // --------------------------------------------------- detail ---
            Page {
                id: detail
                width: parent.width - side.width - 1
                height: parent.height
                visible: app.selected !== null
                title: Disks.displayName(app.selected)
                subtitle: app.selected ? [Disks.humanSize(app.selected.size), app.selected.kind === "disk" ? (app.selected.transport || "").toUpperCase() : (app.selected.fstype || "unformatted"), app.selected.path].filter(s => s).join(" · ") : ""

                // The drive as a bar of its volumes.
                Section {
                    title: "Volumes on " + Disks.displayName(app.disk)
                    Item {
                        width: parent.width; height: Tokens.islandHeight * 2.6
                        Row {
                            id: map
                            anchors { fill: parent; margins: Tokens.padding }
                            spacing: 2
                            readonly property var parts: app.disk ? app.disk.partitions.filter(p => p.kind === "partition") : []
                            // Another drive: its volumes grow out from the left.
                            property real grow: 1
                            Connections {
                                target: app
                                function onDiskNameChanged() {
                                    if (!Motion.enabled) return;
                                    map.grow = 0;
                                    growIn.restart();
                                }
                            }
                            NumberAnimation { id: growIn; target: map; property: "grow"; to: 1; duration: Motion.emphasized; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                            Repeater {
                                model: map.parts
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    readonly property real share: app.disk && app.disk.size ? modelData.size / app.disk.size : 0
                                    width: Math.max(6, (map.width - 2 * map.parts.length) * share) * map.grow
                                    height: map.height
                                    readonly property bool picked: app.selected && app.selected.name === modelData.name
                                    scale: picked ? 1 : pm.containsMouse ? 0.985 : 0.96
                                    Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.bouncy } }
                                    radius: Tokens.radiusInner * 0.6
                                    color: Qt.hsla((0.58 + index * 0.13) % 1, 0.55, Colors.dark ? 0.55 : 0.5, app.selected && app.selected.name === modelData.name ? 1 : 0.7)
                                    border.width: app.selected && app.selected.name === modelData.name ? 2 : 0; border.color: Colors.text
                                    Label { anchors.centerIn: parent; width: parent.width - 6; horizontalAlignment: Text.AlignHCenter; visible: parent.width > 60
                                            text: Disks.displayName(modelData) + "\n" + Disks.humanSize(modelData.size); size: Tokens.textSmall; color: "white"; maximumLineCount: 2; wrapMode: Text.NoWrap }
                                    MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: app.selected = modelData }
                                }
                            }
                            Rectangle {
                                visible: app.disk && app.disk.freeSpace > app.disk.size * 0.01
                                width: app.disk ? Math.max(6, (map.width - 2 * map.parts.length) * app.disk.freeSpace / app.disk.size) * map.grow : 0
                                height: map.height; radius: Tokens.radiusInner * 0.6
                                color: Colors.alpha(Colors.text, 0.08)
                                Label { anchors.centerIn: parent; visible: parent.width > 60; text: "Free\n" + (app.disk ? Disks.humanSize(app.disk.freeSpace) : ""); size: Tokens.textSmall; role: "dim"; horizontalAlignment: Text.AlignHCenter }
                            }
                        }
                    }
                }
                Section {
                    title: "Information"
                    Info { k: "Mount point"; v: app.selected ? (app.selected.mountpoint || "Not mounted") : "" }
                    Info { k: "Format"; v: app.selected ? (app.selected.fstype || app.selected.partTypeName || "—") : "" }
                    Info { k: "Used"; v: app.selected && app.selected.fssize ? Disks.humanSize(app.selected.fsused) + " of " + Disks.humanSize(app.selected.fssize) : "—" }
                    Info { k: "Label"; v: app.selected ? (app.selected.label || "—") : "" }
                    Info { k: "UUID"; v: app.selected ? (app.selected.uuid || "—") : "" }
                    Info { k: "Device"; v: app.selected ? app.selected.path + (app.selected.readOnly ? " (read-only)" : "") : ""; last: true }
                }
                Label {
                    visible: app.locked
                    width: parent.width; wrapMode: Text.WordWrap; elide: Text.ElideNone
                    text: "This drive holds the running system (/ or /boot). Disk Utility does not change it."
                    role: "dim"
                }
                Flow {
                    visible: !app.locked && app.selected !== null
                    width: parent.width
                    spacing: Tokens.gap
                    Action { text: "Mount"; shown: app.selected && app.selected.kind !== "disk" && !app.selected.mountpoint && !!app.selected.fstype; onClicked: Disks.mount(app.selected) }
                    Action { text: "Unmount"; shown: app.selected && !!app.selected.mountpoint; onClicked: Disks.unmount(app.selected) }
                    Action { text: "Eject"; shown: app.disk && (app.disk.removable || app.disk.hotplug); onClicked: Disks.eject(app.disk) }
                    Action { text: "First aid"; shown: app.selected && app.selected.kind !== "disk" && !!app.selected.fstype; onClicked: Disks.firstAid(app.selected) }
                    Action { text: "Rename"; shown: app.selected && app.selected.kind !== "disk" && !!app.selected.fstype; onClicked: sheet.open("rename") }
                    Action { text: "Erase…"; danger: true; shown: app.selected !== null; onClicked: sheet.open("erase") }
                    Action { text: "Partition table…"; danger: true; shown: app.selected && app.selected.kind === "disk"; onClicked: sheet.open("table") }
                    Action { text: "Delete…"; danger: true; shown: app.selected && app.selected.kind === "partition"; onClicked: sheet.open("delete") }
                }
                Row {
                    visible: Disks.busyMessage.length > 0 || app.message.length > 0
                    spacing: Tokens.gap
                    Icon { name: Disks.busyMessage ? "timer" : app.messageOk ? "check" : "close"; color: Disks.busyMessage ? Colors.textDim : app.messageOk ? Colors.accent : Colors.danger }
                    Label { text: Disks.busyMessage || app.message; role: Disks.busyMessage ? "dim" : app.messageOk ? "text" : "danger"; wrapMode: Text.WordWrap; elide: Text.ElideNone; width: 560 }
                }
            }
        }

        ConfirmSheet { id: sheet; anchors.fill: parent; target: app.selected }
    }

    // ------------------------------------------------------- components ---
    component Entry: Rectangle {
        id: e
        property var item: null
        property int depth: 0
        readonly property bool on: app.selected && item && app.selected.name === item.name
        width: list.width
        height: Tokens.islandHeight * (depth === 0 ? 1.5 : 1.2)
        radius: Tokens.radiusInner
        color: on ? Colors.accent : em.containsMouse ? Colors.alpha(Colors.text, 0.08) : "transparent"
        Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
        Row {
            // Leans towards the pointer.
            anchors { fill: parent; leftMargin: Tokens.gap + e.depth * Tokens.padding + (em.containsMouse && !e.on ? 5 : 0) }
            Behavior on anchors.leftMargin { enabled: Motion.enabled; SpringAnim { token: Motion.bouncy } }
            spacing: Tokens.gap
            Icon { name: e.depth === 0 ? "folder" : "file"; anchors.verticalCenter: parent.verticalCenter; color: e.on ? Colors.onAccent : Colors.textDim; size: Tokens.iconSize * (e.depth === 0 ? 1.1 : 0.9) }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Tokens.iconSize * 2
                Label { width: parent.width; text: Disks.displayName(e.item); role: e.on ? "onAccent" : "text"; font.weight: e.depth === 0 ? Font.DemiBold : Font.Normal }
                Label { width: parent.width; text: e.item ? Disks.humanSize(e.item.size) + (e.item.mountpoint ? " · " + e.item.mountpoint : "") : ""; size: Tokens.textSmall; role: e.on ? "onAccent" : "dim" }
            }
        }
        MouseArea { id: em; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: app.selected = e.item }
    }
    component Info: SettingRow {
        property string k: ""
        property string v: ""
        property bool last: false
        label: k; divider: !last
        Label { text: v; role: "dim"; numeric: true; anchors.verticalCenter: parent.verticalCenter }
    }
    component Action: Rectangle {
        id: a
        property string text: ""
        property bool danger: false
        property bool shown: true
        signal clicked()
        visible: shown
        height: Tokens.islandHeight * 1.2; radius: height / 2; width: al.implicitWidth + Tokens.padding * 2
        color: am.containsMouse ? (danger ? Colors.alpha(Colors.danger, 0.25) : Colors.alpha(Colors.text, 0.12)) : Colors.alpha(Colors.text, 0.06)
        Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
        scale: am.pressed ? 0.94 : 1
        Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.bouncy } }
        enabled: !Disks.busyMessage
        opacity: enabled ? 1 : 0.5
        Label { id: al; anchors.centerIn: parent; text: a.text; role: a.danger ? "danger" : "text"; font.weight: Font.DemiBold }
        MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: a.clicked() }
    }
}
