import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components
import "../../lib/wallpaper.js" as Lib

/*
 * The wallpaper picker (Mod+Alt+B, vitrum-ipc wallpaper picker): the folder's
 * wallpapers as a carousel over a preview of the highlighted one.
 *
 *   ← → / wheel   browse          type        filter by name
 *   Enter / click apply           Tab         every screen ↔ this screen
 *   Escape        close
 *
 * The new wallpaper grows out of the card it was picked from.
 */
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property bool open: UiState.wallpaperPicker && !!modelData && modelData.name === (Niri.focusedOutput || Quickshell.screens[0].name)

    MapGate { id: gate; want: root.open }
    visible: gate.mapped
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "vitrum-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    BlurKick { id: blurKick; window: root }
    BackgroundEffect.blurRegion: Materials.wantsRegion("overlay") && !blurKick.on ? effect : blurKick.none
    Region {
        id: effect
        item: gate.mapped ? searchBox : dot; radius: gate.mapped ? searchBox.radius : 0
        Region { item: gate.mapped && caption.visible ? caption : dot; radius: gate.mapped ? caption.radius : 0 }
    }
    Item { id: dot; width: 1; height: 1 }

    property var all: []                 // every file in the folder
    property string query: ""
    property bool everyScreen: true
    readonly property var files: query.trim() ? all.filter(f => f.split("/").pop().toLowerCase().indexOf(query.trim().toLowerCase()) >= 0) : all
    readonly property string current: Wallpaper.pathFor(modelData ? modelData.name : "")
    readonly property string home: Quickshell.env("HOME")
    readonly property string thumbs: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/vitrum/thumbs"

    onOpenChanged: if (open) { query = ""; search.text = ""; lister.running = true; search.forceActiveFocus(); }
    Process {
        id: lister
        command: ["sh", "-c", 'find "$1" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" -o -iname "*.gif" \\) | sort', "_", Wallpaper.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                root.all = text.split("\n").filter(s => s);
                const i = root.files.indexOf(root.current);
                strip.currentIndex = i >= 0 ? i : 0;
                strip.positionViewAtIndex(strip.currentIndex, ListView.Center);
            }
        }
    }
    onFilesChanged: if (strip.currentIndex >= files.length) strip.currentIndex = Math.max(0, files.length - 1)

    // Videos get a frame from ffmpegthumbnailer, cached by path.
    function hash(s) { let h = 5381; for (let i = 0; i < s.length; i++) h = ((h << 5) + h + s.charCodeAt(i)) >>> 0; return h.toString(16); }
    function thumbFor(path) { return thumbs + "/" + hash(path) + ".jpg"; }
    property var made: ({})
    Process { id: thumbProc; onExited: { const m = Object.assign({}, root.made); m[thumbProc.pending] = true; root.made = m; root.nextThumb(); } property string pending: "" }
    property var queue: []
    function wantThumb(path) { if (made[path] || queue.indexOf(path) >= 0) return; queue = queue.concat([path]); if (!thumbProc.running) nextThumb(); }
    function nextThumb() {
        if (!queue.length) return;
        const p = queue[0]; queue = queue.slice(1);
        thumbProc.pending = p;
        thumbProc.command = ["sh", "-c", 'mkdir -p "$(dirname "$2")"; [ -s "$2" ] || ffmpegthumbnailer -i "$1" -o "$2" -s 640 -q 8 >/dev/null 2>&1', "_", p, thumbFor(p)];
        thumbProc.running = true;
    }
    function source(path) {
        if (!path) return "";
        if (Lib.isVideo(path)) { wantThumb(path); return made[path] ? "file://" + thumbFor(path) : ""; }
        return "file://" + path;
    }

    function apply() {
        const path = files[strip.currentIndex];
        if (!path) return;
        const card = strip.currentItem;
        const pos = card ? card.mapToItem(null, card.width / 2, card.height / 2) : null;
        Wallpaper.set(path, everyScreen ? "" : modelData.name, pos ? { x: pos.x, y: pos.y } : null);
        UiState.wallpaperPicker = false;
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: root.open ? 1 : 0
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.standard } }

        // The highlighted wallpaper, full screen, under a dim.
        Image {
            id: preview
            anchors.fill: parent
            source: root.open ? root.source(root.files[strip.currentIndex] || "") : ""
            sourceSize: Qt.size(root.width / 2, root.height / 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
        }
        Rectangle { anchors.fill: parent; color: Colors.alpha("#000000", 0.5) }
        MouseArea { anchors.fill: parent; onClicked: UiState.wallpaperPicker = false
                    onWheel: w => { strip.currentIndex = Math.max(0, Math.min(root.files.length - 1, strip.currentIndex + (w.angleDelta.y < 0 || w.angleDelta.x < 0 ? 1 : -1))); } }

        // Search and target.
        Surface {
            id: searchBox
            group: "overlay"
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.12
            width: Tokens.islandHeight * 16
            height: Tokens.islandHeight * 1.5
            radius: height / 2
            Row {
                anchors { fill: parent; leftMargin: Tokens.padding; rightMargin: Tokens.gap }
                spacing: Tokens.gap
                Icon { name: "search"; color: Colors.textDim; anchors.verticalCenter: parent.verticalCenter }
                TextInput {
                    id: search
                    width: parent.width - Tokens.iconSize - Tokens.gap * 2 - target.width
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Tokens.fontText; font.pixelSize: Tokens.textLarge
                    color: Colors.text; clip: true
                    onTextChanged: root.query = text
                    Label { visible: !search.text; text: root.all.length ? root.all.length + " wallpapers — type to filter" : "No wallpapers in " + Settings.get("wallpaper.dir", "~/Pictures/Wallpapers"); role: "dim"; size: Tokens.textLarge; anchors.verticalCenter: parent.verticalCenter }
                    Keys.onPressed: e => {
                        const k = e.key;
                        if (k === Qt.Key_Escape) UiState.wallpaperPicker = false;
                        else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.apply();
                        else if (k === Qt.Key_Right || k === Qt.Key_Down) strip.incrementCurrentIndex();
                        else if (k === Qt.Key_Left || k === Qt.Key_Up) strip.decrementCurrentIndex();
                        else if (k === Qt.Key_Tab) root.everyScreen = !root.everyScreen;
                        else return;
                        e.accepted = true;
                    }
                }
                Rectangle {
                    id: target
                    anchors.verticalCenter: parent.verticalCenter
                    height: Tokens.islandHeight * 1.1; radius: height / 2; width: tl.implicitWidth + Tokens.padding * 1.4
                    color: Colors.alpha(Colors.accent, 0.22)
                    visible: Quickshell.screens.length > 1
                    Label { id: tl; anchors.centerIn: parent; text: root.everyScreen ? "Every screen" : root.modelData.name; size: Tokens.textSmall + 1 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.everyScreen = !root.everyScreen }
                }
            }
        }

        // The carousel.
        ListView {
            id: strip
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: parent.height * 0.06
            width: parent.width
            height: cardH * 1.25
            orientation: ListView.Horizontal
            spacing: Tokens.gap * 2
            model: root.files
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: (width - cardW) / 2
            preferredHighlightEnd: (width + cardW) / 2
            highlightMoveDuration: Motion.enabled ? Motion.standard : 0
            clip: false
            cacheBuffer: cardW * 4
            readonly property real cardW: Math.min(root.width * 0.3, 560)
            readonly property real cardH: cardW * 0.6
            delegate: Item {
                id: card
                required property string modelData
                required property int index
                readonly property bool isCurrent: ListView.isCurrentItem
                readonly property bool applied: modelData === root.current
                width: strip.cardW; height: strip.height
                scale: isCurrent ? 1 : 0.78
                opacity: isCurrent ? 1 : 0.6
                z: isCurrent ? 2 : 1
                Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }
                Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
                ClippingRectangle {
                    id: frame
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: strip.cardW; height: strip.cardH
                    radius: Tokens.radiusPanel
                    color: Colors.alpha(Colors.surface, 0.9)
                    border.width: card.isCurrent ? 3 : 0
                    border.color: Colors.accent
                    Image {
                        anchors.fill: parent
                        source: root.source(card.modelData)
                        sourceSize.width: 640
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
                    }
                    Icon { anchors.centerIn: parent; visible: Lib.isVideo(card.modelData) && !root.made[card.modelData]; name: "video"; size: Tokens.iconSize * 3; color: Colors.textDim }
                    Rectangle {
                        visible: Lib.isVideo(card.modelData) || card.applied
                        anchors { left: parent.left; top: parent.top; margins: Tokens.gap }
                        height: Tokens.islandHeight; radius: height / 2; width: badge.implicitWidth + Tokens.padding
                        color: Colors.alpha("#000000", 0.55)
                        Label { id: badge; anchors.centerIn: parent; text: (card.applied ? "Current" : "") + (card.applied && Lib.isVideo(card.modelData) ? " · " : "") + (Lib.isVideo(card.modelData) ? "Live" : ""); color: "white"; size: Tokens.textSmall }
                    }
                }
                MouseArea {
                    anchors.fill: frame
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (card.isCurrent) root.apply(); else strip.currentIndex = card.index; }
                }
            }
        }

        // Name and position, in a capsule so they read over any picture.
        Surface {
            id: caption
            group: "overlay"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: strip.bottom
            visible: root.files.length > 0
            width: capCol.implicitWidth + Tokens.padding * 2.4
            height: capCol.implicitHeight + Tokens.padding
            radius: height / 2
            Column {
                id: capCol
                anchors.centerIn: parent
                spacing: 2
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: (root.files[strip.currentIndex] || "").split("/").pop(); size: Tokens.textLarge; font.weight: Font.DemiBold }
                Label { anchors.horizontalCenter: parent.horizontalCenter; role: "dim"; size: Tokens.textSmall
                        text: (strip.currentIndex + 1) + " / " + root.files.length + "   ·   Enter applies   ·   Tab: " + (root.everyScreen ? "every screen" : "this screen") }
            }
        }
    }
}
