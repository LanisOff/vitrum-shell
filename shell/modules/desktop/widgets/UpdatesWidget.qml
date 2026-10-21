import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components

/*
 * The package updates waiting (Packages: emerge @world on Gentoo, checkupdates
 * on Arch, xbps-install -Mun on Void, dnf check-update on Fedora). A click
 * opens the bar's updates panel: the list, and a way to update.
 *   S   how many, large, "updates" under it
 *   M   the header; how many; the first packages beside it
 * None waiting: a check and "Up to date".
 * options: list (name the packages at M).
 * In a gallery card with nothing waiting, a sample of twelve stands in.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    readonly property bool sample: preview && Packages.updates.length === 0
    readonly property var updates: sample
        ? ["mesa", "linux-firmware", "firefox", "pipewire", "qt6-base", "python", "systemd", "openssl", "glib2", "gtk4", "curl", "harfbuzz"]
            .map((n, i) => ({ atom: n, from: "1." + i, to: "1." + (i + 1), kind: "update" }))
        : Packages.updates
    readonly property int count: updates.length
    readonly property bool none: Packages.backend === "" && !preview
    readonly property bool showList: options.list !== false
    // "sys-devel/gcc-14.2.1" → "gcc-14.2.1": the category is noise at this size.
    function pkgName(atom) { return String(atom || "").split("/").pop(); }

    WidgetHeader {
        id: head
        visible: root.sizeClass !== "S"
        height: visible ? implicitHeight : 0
        icon: "update"; title: "Updates"
        trailing: Packages.checking ? "Checking…" : Packages.state.running ? "Updating…" : ""
    }
    WidgetEmpty {
        visible: root.none
        icon: "update"
        text: "No package manager found"
    }

    // ---- nothing waiting.
    Column {
        visible: !root.none && root.count === 0
        anchors.centerIn: parent
        anchors.verticalCenterOffset: head.height / 2
        spacing: Tokens.gap * 0.5
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(Math.min(root.width, root.height - head.height) * 0.36); height: width; radius: width / 2
            color: Colors.alpha(Colors.accent, Colors.dark ? 0.22 : 0.16)
            Icon { anchors.centerIn: parent; name: "check"; size: Math.round(parent.width * 0.58); color: Colors.accent }
        }
        Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Up to date"; font.weight: Font.Medium }
    }

    // ---- S: how many.
    Column {
        visible: !root.none && root.count > 0 && root.sizeClass === "S"
        anchors.centerIn: parent
        spacing: 0
        Metric {
            anchors.horizontalCenter: parent.horizontalCenter
            value: String(root.count)
            size: Math.round(root.height * 0.36)
            color: Colors.accent
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.count === 1 ? "update" : "updates"
            role: "dim"; size: Tokens.textSmall
        }
    }

    // ---- M: how many, the first of them beside it.
    Metric {
        id: big
        visible: !root.none && root.count > 0 && root.sizeClass !== "S"
        anchors { left: parent.left; top: head.bottom; topMargin: Tokens.gap * 0.6 }
        value: String(root.count)
        label: root.count === 1 ? "update" : "updates"
        size: Math.max(28, Math.min(56, (root.height - head.height) * 0.48))
        color: Colors.accent
    }
    Column {
        id: names
        visible: !root.none && root.count > 0 && root.sizeClass !== "S" && root.showList
        anchors { left: big.right; leftMargin: Tokens.gap * 2; right: parent.right; top: head.bottom; topMargin: Tokens.gap * 0.4; bottom: parent.bottom }
        readonly property real rowH: Math.round(Tokens.textSize * 1.7)
        readonly property int fits: Math.max(1, Math.floor(height / rowH))
        Repeater {
            // The last row says how many more there are, when not all fit.
            model: {
                const max = Math.min(5, names.fits), n = root.count;
                const rows = root.updates.slice(0, n > max ? max - 1 : max).map(u => ({ title: root.pkgName(u.atom), trailing: u.to || "" }));
                if (n > max) rows.push({ title: "and " + (n - max + 1) + " more", trailing: "", more: true });
                return rows;
            }
            delegate: ListRow {
                required property var modelData
                width: names.width
                height: names.rowH
                title: modelData.title
                trailing: modelData.trailing
                dim: !!modelData.more
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.preview
        cursorShape: Qt.PointingHandCursor
        // As `qs ipc call panel open updates` does: on the focused screen, from the top.
        onClicked: {
            const s = Quickshell.screens.find(x => x.name === Niri.focusedOutput) || Quickshell.screens[0];
            if (s) UiState.openPanel("updates", s, Qt.rect(s.width / 2 - 60, Tokens.gap, 120, Tokens.islandHeight));
        }
    }
}
