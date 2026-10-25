import QtQuick
import qs.services
import qs.theme
import qs.components
import qs.backend

/*
 * The one place a destructive action starts: a sheet over the window that
 * says what will be lost, and for erase / partition table / delete asks for
 * the volume's name to be typed. The backend checks that name again.
 */
Item {
    id: sheet
    property var target: null
    property string mode: ""            // rename | erase | table | delete
    readonly property string name: Disks.displayName(picked)
    readonly property bool destructive: mode === "erase" || mode === "table" || mode === "delete"
    property string fs: "ext4"
    property string scheme: "gpt"
    visible: mode !== ""
    // Rises in over a darkening window; mode is cleared only once it has gone,
    // so the words do not change while it fades out.
    property bool shown: false
    opacity: shown ? 1 : 0
    Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
    Timer { id: gone; interval: Motion.enabled ? Motion.fast : 0; onTriggered: sheet.mode = "" }

    // The device is fixed when the sheet opens; a new selection closes the sheet.
    property var picked: null
    onTargetChanged: if (mode && (!target || !picked || target.name !== picked.name)) close()
    function open(m) { gone.stop(); shown = true; picked = target; mode = m; label.text = m === "rename" ? (picked ? picked.label : "") : ""; confirm.text = ""; label.forceActiveFocus(); }
    function close() { shown = false; gone.restart(); }
    function go() {
        if (destructive && confirm.text !== name) return;
        if (mode === "rename") Disks.rename(picked, label.text);
        else if (mode === "erase") Disks.erase(picked, label.text || "Untitled", fs, confirm.text);
        else if (mode === "table") Disks.repartition(picked, scheme, confirm.text);
        else if (mode === "delete") Disks.deletePartition(picked, confirm.text);
        close();
    }

    Rectangle { anchors.fill: parent; color: Colors.alpha("#000000", 0.45); MouseArea { anchors.fill: parent; onClicked: sheet.close() } }
    Surface {
        anchors.centerIn: parent
        transform: Translate { y: sheet.shown ? 0 : 36; Behavior on y { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } } }
        scale: sheet.shown ? 1 : 0.94
        Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }
        width: 520
        height: col.implicitHeight + Tokens.padding * 2
        group: "dialogs"
        // Solid, as apps/common's Sheet: an app window has no blur behind it,
        // and the details under the glass read through the form.
        color: Colors.bg
        MouseArea { anchors.fill: parent }
        Column {
            id: col
            x: Tokens.padding * 1.5; y: Tokens.padding
            width: parent.width - Tokens.padding * 3
            spacing: Tokens.gap * 1.5
            Label {
                text: sheet.mode === "rename" ? "Rename “" + sheet.name + "”" : sheet.mode === "erase" ? "Erase “" + sheet.name + "”?"
                    : sheet.mode === "table" ? "New partition table on “" + sheet.name + "”?" : "Delete “" + sheet.name + "”?"
                size: Tokens.textLarge; font.weight: Font.DemiBold; width: parent.width; wrapMode: Text.WordWrap; elide: Text.ElideNone
            }
            Label {
                visible: sheet.destructive
                width: parent.width; wrapMode: Text.WordWrap; elide: Text.ElideNone; role: "dim"
                text: sheet.mode === "table" ? "Every partition on this drive and everything in them is lost." : "Everything on it is lost. This cannot be undone."
            }
            Field { id: label; visible: sheet.mode === "rename" || sheet.mode === "erase"; placeholder: "Name" }
            Row {
                visible: sheet.mode === "erase"
                spacing: 4
                Repeater {
                    model: ["ext4", "btrfs", "xfs", "exfat", "fat32", "ntfs"]
                    delegate: Choice { required property string modelData; label: modelData; primary: sheet.fs === modelData; onClicked: sheet.fs = modelData }
                }
            }
            Row {
                visible: sheet.mode === "table"
                spacing: 4
                Repeater {
                    model: [{ v: "gpt", t: "GPT" }, { v: "msdos", t: "MBR (old PCs)" }]
                    delegate: Choice { required property var modelData; label: modelData.t; primary: sheet.scheme === modelData.v; onClicked: sheet.scheme = modelData.v }
                }
            }
            Label { visible: sheet.destructive; width: parent.width; wrapMode: Text.WordWrap; elide: Text.ElideNone; text: "Type “" + sheet.name + "” to confirm:" }
            Field { id: confirm; visible: sheet.destructive; placeholder: sheet.name }
            Row {
                anchors.right: parent.right
                spacing: Tokens.gap
                Choice { label: "Cancel"; onClicked: sheet.close() }
                // The action: tinted, from the danger colour when it destroys something.
                Choice {
                    label: sheet.mode === "rename" ? "Rename" : sheet.mode === "erase" ? "Erase" : sheet.mode === "table" ? "Create" : "Delete"
                    primary: true; danger: sheet.destructive
                    enabled: !sheet.destructive || confirm.text === sheet.name
                    onClicked: sheet.go()
                }
            }
        }
    }
    Keys.onEscapePressed: close()

    // A glass field, as apps/common's Field; Enter goes ahead.
    component Field: Surface {
        property alias text: inp.text
        property string placeholder: ""
        function forceActiveFocus() { inp.forceActiveFocus(); }
        width: col.width; height: Tokens.islandHeight * 1.2; radius: Tokens.radiusButton
        group: "dialogs"; level: 1
        border.width: inp.activeFocus ? 2 : Tokens.hairline
        border.color: inp.activeFocus ? Colors.accent : Materials.border(group)
        TextInput {
            id: inp
            anchors { fill: parent; leftMargin: Tokens.gap; rightMargin: Tokens.gap }
            verticalAlignment: TextInput.AlignVCenter
            font.family: Tokens.fontText; font.pixelSize: Tokens.textSize; color: Colors.text; clip: true
            onAccepted: sheet.go()
            Label { visible: !inp.text; text: parent.parent.placeholder; role: "dim"; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    // A button on the sheet: a format or scheme to pick (tinted when picked),
    // Cancel, or the action.
    component Choice: GlassButton {
        group: "dialogs"
        height: Tokens.islandHeight * 1.15
    }
}
