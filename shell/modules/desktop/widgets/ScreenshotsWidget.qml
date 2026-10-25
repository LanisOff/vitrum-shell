import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import "../../../lib/shots.js" as Lib

/*
 * The latest screenshots, from the capture folder (capture.dir), as glass
 * thumbnails. Listed again after each capture the shell takes, when the
 * folder setting changes, and when files come and go there (other tools
 * save there too: the folder is watched, nothing polls).
 *   M   the header, the folder button at its end; the newest three in a row
 *   L   the newest four, two by two, each with when it was taken
 *   XL  the newest six, three by two
 * A click opens one (xdg-open); the folder button opens the folder. A
 * thumbnail lifts under the pointer.
 * options: times (when each was taken, under it, at L and XL).
 * In a gallery card, sample pictures; nothing is listed or opened.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    // preview is set after Component.onCompleted: start a turn later, once it is known.
    property bool started: false
    Component.onCompleted: Qt.callLater(() => { root.started = true; root.relist(); })
    readonly property bool live: started && !preview

    readonly property string dir: Capture.dir
    readonly property int cols: sizeClass === "M" ? 3 : sizeClass === "L" ? 2 : 3
    readonly property int lines: sizeClass === "M" ? 1 : 2
    readonly property bool times: options.times !== false && sizeClass !== "M"
    readonly property bool h24: Settings.get("clock.h24", true)

    property var found: []
    property bool listed: false
    readonly property var sample: [0, 1, 2, 3, 4, 5].map(i => ({ path: "", time: Date.now() - (i * 7 + 2) * 3600 * 1000, hue: [210, 30, 280, 150, 340, 190][i] }))
    readonly property var shots: (preview ? sample : found).slice(0, cols * lines)

    Process {
        id: lister
        command: ["sh", "-c", "find \"$1\" -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\) -printf '%T@\\t%p\\n' 2>/dev/null | sort -rn | head -n 6",
                  "_", root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                root.found = Lib.parseList(text, 6);
                root.listed = true;
                // A folder made since (by the first capture) is watched from now
                // on: a watch set up before it existed sees nothing.
                if (root.found.length > 0 && watch.count === 0) root.rewatch++;
            }
        }
    }
    property bool _again: false
    function relist() {
        if (!live) return;
        if (lister.running) { _again = true; return; }
        lister.running = true;
    }
    Connections {
        target: lister
        function onRunningChanged() { if (!lister.running && root._again) { root._again = false; root.relist(); } }
    }
    onDirChanged: relist()
    // A capture of the shell's own: the file is written by now.
    Connections { target: Capture; function onLastChanged() { root.relist(); } }
    // Only a watch: a file added or removed there lists the folder again
    // (find sorts by time; the model is never shown).
    property int rewatch: 0
    FolderListModel {
        id: watch
        folder: root.live && root.dir ? "file://" + root.dir + (root.rewatch % 2 ? "/" : "") : ""
        showDirs: false
        caseSensitive: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        onCountChanged: relistLater.restart()
    }
    Timer { id: relistLater; interval: 400; onTriggered: root.relist() }
    // The "Today 14:05" labels roll over at midnight with the next listing; the time is read then.
    property real now: Date.now()
    onFoundChanged: now = Date.now()

    function open(path) { if (live && path) Quickshell.execDetached(["xdg-open", path]); }

    WidgetHeader {
        id: head
        icon: "screenshot"; title: "Screenshots"
    }
    GlassButton {
        anchors { right: parent.right; verticalCenter: head.verticalCenter }
        height: head.height; width: height
        group: "widgets"
        icon: "folder"
        enabled: !root.preview
        onClicked: Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && exec xdg-open "$1"', "_", root.dir])
    }
    WidgetEmpty {
        visible: root.shots.length === 0 && (root.listed || root.preview)
        anchors.verticalCenterOffset: head.height / 2
        icon: "screenshot"
        text: "No screenshots yet"
    }

    Grid {
        id: grid
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: Tokens.gap * 0.6; bottom: parent.bottom }
        columns: root.cols
        spacing: Math.round(Tokens.gap * 0.8)
        readonly property real cellW: (width - (columns - 1) * spacing) / columns
        readonly property real cellH: (height - (root.lines - 1) * spacing) / root.lines
        readonly property real labelH: root.times ? Tokens.textSmall + Math.round(Tokens.gap * 0.5) : 0
        Repeater {
            model: root.shots
            delegate: Item {
                id: cell
                required property var modelData
                width: grid.cellW; height: grid.cellH

                Item {
                    id: thumb
                    width: parent.width; height: parent.height - grid.labelH
                    // Lifts a little under the pointer, sinks when pressed: damped.
                    scale: mouse.pressed ? 0.97 : mouse.containsMouse ? 1.03 : 1
                    Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }
                    readonly property real rim: Math.max(2, Math.round(Tokens.gap * 0.25))
                    // The glass the picture sits in: a rim of the widgets' material around it.
                    Surface {
                        anchors.fill: parent
                        group: "widgets"
                        level: 1
                        radius: Tokens.radiusTile
                    }
                    Rectangle {
                        anchors { fill: parent; margins: thumb.rim }
                        visible: root.preview
                        radius: Tokens.radiusTile - thumb.rim
                        gradient: Gradient {
                            GradientStop { position: 0; color: Colors.ink(cell.modelData.hue || 0) }
                            GradientStop { position: 1; color: Colors.ink((cell.modelData.hue || 0) + 70) }
                        }
                        Rectangle {
                            x: parent.width * 0.12; y: parent.height * 0.18
                            width: parent.width * 0.5; height: parent.height * 0.12; radius: height / 2
                            color: Qt.rgba(1, 1, 1, 0.45)
                        }
                    }
                    RoundImage {
                        id: pic
                        anchors { fill: parent; margins: thumb.rim }
                        visible: !root.preview
                        radius: Tokens.radiusTile - thumb.rim
                        sourceWidth: Math.round(width * 2)
                        source: cell.modelData.path ? Lib.fileUrl(cell.modelData.path) : ""
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: !root.preview && pic.status !== Image.Ready
                        name: "image"; size: Math.round(Math.min(parent.width, parent.height) * 0.3); color: Colors.textDim
                    }
                    // The lift's light: a faint veil of the text colour.
                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.radiusTile
                        color: Colors.alpha(Colors.text, mouse.containsMouse ? 0.08 : 0)
                        Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
                    }
                }
                Label {
                    visible: root.times
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: grid.labelH
                    horizontalAlignment: Text.AlignHCenter
                    text: Lib.when(cell.modelData.time, root.now, root.h24)
                    role: "dim"; size: Tokens.textSmall; numeric: true
                }
                MouseArea {
                    id: mouse
                    anchors.fill: thumb
                    enabled: !root.preview
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.open(cell.modelData.path)
                }
            }
        }
    }
}
