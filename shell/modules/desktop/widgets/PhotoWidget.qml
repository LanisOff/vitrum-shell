import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components

/*
 * A photo frame: the pictures in a folder (and the folders right under it),
 * one at a time, each fading into the next.
 *   S–XL  the photo fills the whole plate, edge to edge, its corners the plate's.
 * options: folder ("~" is home), interval (seconds), shuffle.
 * The folder is listed again when it changes and every ten minutes.
 * In a gallery card a gradient stands in for the photo; nothing is listed.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    readonly property string folderOption: String(options.folder || "~/Pictures")
    readonly property string folder: {
        const f = folderOption;
        const home = Quickshell.env("HOME") || "";
        return f === "~" ? home : f.indexOf("~/") === 0 ? home + f.slice(1) : f;
    }
    readonly property int intervalMs: Math.max(5, Number(options.interval) || 30) * 1000
    readonly property bool shuffle: options.shuffle !== false

    property var photos: []
    property bool listed: false
    property int index: -1

    // ------------------------------------------------------- listing ---
    Process {
        id: lister
        command: ["sh", "-c", "find \"$1\" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | head -500",
                  "_", root.folder]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = text.split("\n").filter(l => l.length > 0).sort();
                const had = root.photos.length > 0 && root.index >= 0 ? root.photos[root.index] : "";
                root.photos = list;
                root.listed = true;
                // Keep the photo on show if it is still there; else start afresh.
                const at = list.indexOf(had);
                if (at >= 0) root.index = at;
                else { root.index = -1; root.next(); }
            }
        }
    }
    // Deferred: the host sets options, then preview, right after this item is
    // made, and a gallery card must not run find.
    function relist() { Qt.callLater(_relist); }
    property bool _again: false
    function _relist() {
        if (preview) return;
        if (lister.running) { _again = true; return; }
        lister.running = true;
    }
    Connections {
        target: lister
        function onRunningChanged() { if (!lister.running && root._again) { root._again = false; root._relist(); } }
    }
    onFolderChanged: { listed = false; relist(); }
    Component.onCompleted: relist()
    Timer { interval: 10 * 60 * 1000; repeat: true; running: !root.preview; onTriggered: root.relist() }

    // ------------------------------------------------------ stepping ---
    function next() {
        const n = photos.length;
        if (!n) return;
        if (n === 1) index = 0;
        else if (shuffle && index < 0) index = Math.floor(Math.random() * n);
        else if (shuffle) {
            let i = Math.floor(Math.random() * (n - 1));
            index = i >= index ? i + 1 : i;              // never the same one twice
        } else index = (index + 1) % n;
        // Encoded: a "#" or "?" in a file name would otherwise cut the URL short.
        show("file://" + photos[index].split("/").map(encodeURIComponent).join("/"));
    }
    Timer { interval: root.intervalMs; repeat: true; running: !root.preview && root.photos.length > 1; onTriggered: root.next() }

    // Two layers: the next photo loads into the hidden one and fades in once it
    // is ready, so a slow decode never shows a blank frame.
    property int front: 0
    property int pending: -1
    function show(url) {
        const back = front === 0 ? 1 : 0;
        const img = back === 0 ? layerA : layerB;
        if (img.source.toString() === url && img.status === Image.Ready) { front = back; return; }
        pending = back;
        img.source = url;
    }
    function ready(which) {
        if (pending === which) { front = which; pending = -1; }
    }

    // ------------------------------------------------------- drawing ---
    // The host insets content by the padding; the photo reaches back out to the
    // plate's edge and is cut to its corners.
    Item {
        id: photo
        anchors.fill: parent
        anchors.margins: -Tokens.padding
        visible: false
        layer.enabled: true

        // Gallery card: a sample "photo", in the accent's family.
        Rectangle {
            anchors.fill: parent
            visible: root.preview
            gradient: Gradient {
                GradientStop { position: 0; color: Colors.ink(200) }
                GradientStop { position: 0.6; color: Colors.ink(320) }
                GradientStop { position: 1; color: Colors.ink(20) }
            }
            Rectangle {
                width: parent.height * 0.34; height: width; radius: width / 2
                x: parent.width * 0.66; y: parent.height * 0.18
                color: Qt.rgba(1, 1, 1, 0.55)
            }
            Rectangle {
                width: parent.width * 1.4; height: parent.height * 0.9; radius: height / 2
                x: -parent.width * 0.35; y: parent.height * 0.62
                color: Colors.alpha(Colors.ink(140), 0.85)
            }
            Rectangle {
                width: parent.width; height: parent.height * 0.8; radius: height / 2
                x: parent.width * 0.3; y: parent.height * 0.74
                color: Colors.alpha(Colors.ink(160), 0.95)
            }
        }

        Image {
            id: layerA
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: photo.width
            sourceSize.height: photo.height
            opacity: root.front === 0 ? 1 : 0
            Behavior on opacity { enabled: Motion.enabled; NumberAnimation { duration: Motion.emphasized * 2; easing.type: Easing.InOutQuad } }
            onStatusChanged: if (status === Image.Ready) root.ready(0)
        }
        Image {
            id: layerB
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: photo.width
            sourceSize.height: photo.height
            opacity: root.front === 1 ? 1 : 0
            Behavior on opacity { enabled: Motion.enabled; NumberAnimation { duration: Motion.emphasized * 2; easing.type: Easing.InOutQuad } }
            onStatusChanged: if (status === Image.Ready) root.ready(1)
        }
    }
    Rectangle {
        id: mask
        anchors.fill: photo
        radius: Tokens.radiusPanel * 1.25
        visible: false
        layer.enabled: true
        layer.smooth: true
    }
    MultiEffect {
        anchors.fill: photo
        source: photo
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        visible: root.preview || root.photos.length > 0
    }

    WidgetEmpty {
        visible: !root.preview && root.listed && root.photos.length === 0
        icon: "photo"
        text: "No photos in " + root.folderOption
    }
}
