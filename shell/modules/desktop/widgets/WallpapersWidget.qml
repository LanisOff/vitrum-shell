import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import "../../../lib/wallpaper.js" as Lib

/*
 * The wallpaper on this screen (Wallpaper), and a way through the wallpaper
 * folder (wallpaper.dir): the previous one, a random one, the next one.
 *   S   the picture fills the plate, edge to edge; the three keys over its foot
 *   M   the picture on the left; its name, where it is in the folder, and
 *       the keys beside it
 * A click on the picture opens Settings → Wallpaper. A video shows its first
 * frame (the poster Wallpaper makes for it).
 * The folder is listed when it shows, when the folder or the wallpaper
 * changes, and nothing in between. In a gallery card a gradient stands in
 * for the picture; nothing is listed or changed.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    property bool started: false
    Component.onCompleted: Qt.callLater(() => { root.started = true; root.relist(); })
    readonly property bool live: started && !preview

    readonly property bool small: sizeClass === "S"
    readonly property string path: preview ? "" : Wallpaper.pathFor(Screen.name)
    readonly property bool video: Lib.isVideo(path)
    readonly property string image: !path ? "" : video ? Wallpaper.posterOf(path) : path
    readonly property string fileName: preview ? "Dunes at dusk.jpg" : path ? path.split("/").pop() : ""
    readonly property string title: fileName.replace(/\.[A-Za-z0-9]+$/, "").replace(/[-_]+/g, " ")

    property var files: []
    property bool listed: false
    readonly property int at: files.indexOf(path)
    readonly property string position: preview ? "3 of 24" : at >= 0 ? (at + 1) + " of " + files.length
                                       : files.length ? files.length + " in the folder" : ""
    readonly property bool canStep: preview || files.length > 1

    // ------------------------------------------------------- listing ---
    Process {
        id: lister
        command: ["sh", "-c", 'find "$1" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" -o -iname "*.gif" \\) 2>/dev/null | sort | head -2000', "_", Wallpaper.dir]
        stdout: StdioCollector { onStreamFinished: { root.files = text.split("\n").filter(s => s); root.listed = true; } }
    }
    property bool _again: false
    function relist() {
        if (!live) return;
        if (lister.running) { _again = true; return; }
        lister.running = true;
    }
    Connections { target: lister; function onRunningChanged() { if (!lister.running && root._again) { root._again = false; root.relist(); } } }
    Connections { target: Wallpaper; function onDirChanged() { root.relist(); } }
    onPathChanged: if (path && at < 0) relist()

    function step(d) { if (!root.preview) Wallpaper.cycle(d); }
    function openSettings() { if (!root.preview) Quickshell.execDetached(["vitrum-settings", "--pane", "wallpaper"]); }

    // ------------------------------------------------------- drawing ---
    // The picture: S reaches out to the plate's edge, M sits in its own frame.
    Item {
        id: frame
        x: root.small ? -Tokens.padding : 0
        y: root.small ? -Tokens.padding : 0
        width: root.small ? root.width + 2 * Tokens.padding : Math.min(root.height * 16 / 9, root.width * 0.55)
        height: root.small ? root.height + 2 * Tokens.padding : root.height
        readonly property real radius: root.small ? Tokens.radiusPanel * 1.25 : Tokens.radiusTile

        // Gallery card, or nothing to show yet: a sample "picture" in the accent's family.
        Rectangle {
            anchors.fill: parent
            visible: root.preview || shot.status !== Image.Ready
            radius: frame.radius
            gradient: Gradient {
                GradientStop { position: 0; color: root.preview ? Colors.ink(30) : Colors.alpha(Colors.text, 0.06) }
                GradientStop { position: 0.55; color: root.preview ? Colors.ink(330) : Colors.alpha(Colors.text, 0.04) }
                GradientStop { position: 1; color: root.preview ? Colors.ink(250) : Colors.alpha(Colors.text, 0.08) }
            }
            Icon {
                anchors.centerIn: parent
                visible: !root.preview
                name: root.video ? "video" : "image"
                size: Tokens.iconSize * 1.6
                color: Colors.textDim
            }
        }
        RoundImage {
            id: shot
            anchors.fill: parent
            radius: frame.radius
            sourceWidth: Math.round(frame.width * 1.5)
            // Encoded: a "#" or "?" in a file name would otherwise cut the URL short.
            source: root.image ? "file://" + root.image.split("/").map(encodeURIComponent).join("/") : ""
        }
        // The glass's own edge over the picture, so it sits in the plate rather than on it.
        Rectangle {
            anchors.fill: parent
            visible: !root.small
            radius: frame.radius
            color: "transparent"
            border.width: Tokens.hairline
            border.color: Materials.border("widgets")
        }
        MouseArea {
            anchors.fill: parent
            enabled: !root.preview
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openSettings()
        }
    }

    // The three keys: previous, shuffle, next (stepped: -1, 0, 1). Given, not
    // looked up: an inline component does not see this file's ids.
    component Keys: Row {
        id: keys
        signal stepped(int d)
        property real key: Tokens.islandHeight
        property bool usable: true
        property int level: 1
        spacing: Math.round(Tokens.gap * 0.4)
        Repeater {
            model: [{ i: "previous", d: -1 }, { i: "shuffle", d: 0 }, { i: "next", d: 1 }]
            delegate: GlassButton {
                required property var modelData
                width: keys.key; height: keys.key
                group: "widgets"
                level: keys.level
                icon: modelData.i
                enabled: keys.usable
                onClicked: keys.stepped(modelData.d)
            }
        }
    }

    // ---- S: the keys over the picture's foot.
    Keys {
        visible: root.small
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
        key: Math.round(Tokens.islandHeight * 0.95)
        level: 2
        usable: root.canStep
        onStepped: d => root.step(d)
    }

    // ---- M: the name and the keys beside the picture.
    Item {
        visible: !root.small
        anchors { left: frame.right; leftMargin: Tokens.gap; right: parent.right; top: parent.top; bottom: parent.bottom }
        WidgetHeader { id: head; icon: "image"; title: "Wallpaper" }
        Column {
            anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: Tokens.gap * 0.4 }
            spacing: 2
            Label {
                width: parent.width
                text: root.title || "No wallpaper"
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }
            Label { width: parent.width; visible: text.length > 0; text: root.position; role: "dim"; size: Tokens.textSmall; numeric: true }
        }
        Keys {
            anchors { left: parent.left; bottom: parent.bottom }
            key: Math.min(Tokens.islandHeight, (parent.width - 2 * spacing) / 3)
            usable: root.canStep
            onStepped: d => root.step(d)
        }
    }
}
