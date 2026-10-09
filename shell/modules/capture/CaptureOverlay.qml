import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.components
import "../../lib/capture.js" as Lib

/*
 * The capture overlay, one per screen: the frozen frame (live screen for
 * video), a dim outside the selection, the selection with handles and its
 * size, and a capsule toolbar —
 *
 *   [ area | window | screen ]  [ photo | video | text ]  [ delay ] ([ sound ][ mic ])  [ capture ] [ × ]
 *
 * Drag selects (on any screen); drag inside moves it, handles resize it.
 * Enter or the capture button takes it; Escape cancels. In "screen" mode a
 * click takes the screen under the pointer. Keys: 1 2 3 mode, P V T kind,
 * D delay.
 */
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property bool open: UiState.capture
    readonly property bool focused_: screen.name === (Niri.focusedOutput || Quickshell.screens[0].name)
    readonly property real scale_: (Niri.outputs[screen.name] && Niri.outputs[screen.name].scale) || 1
    readonly property var bounds: ({ w: width, h: height })

    // The selection belongs to the screen where it was drawn.
    property var sel: null
    readonly property bool hasSel: sel !== null && !Lib.isClick(sel)
    Connections {
        target: UiState
        function onCaptureChanged() { if (UiState.capture) { root.sel = null; if (root.focused_) keys.forceActiveFocus(); } }
    }
    Connections {
        target: Capture
        function onSelectionClaimed(name) { if (name !== root.screen.name) root.sel = null; }
        function onTestSelect(r, take) { if (root.open && root.focused_) { root.sel = { x: r.x, y: r.y, w: r.width, h: r.height }; if (take) root.take(); } }
    }

    visible: true
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "vitrum-capture"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open && focused_ ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: root.open ? content : dot }
    BlurKick { id: blurKick; window: root }
    BackgroundEffect.blurRegion: Materials.wantsRegion("overlay") && !blurKick.on ? effect : blurKick.none
    Region { id: effect; item: root.open && bar.visible ? bar : dot; radius: root.open && bar.visible ? bar.radius : 0 }
    Item { id: dot; width: 1; height: 1 }

    Item {
        id: content
        anchors.fill: parent
        opacity: root.open ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }

        // The frozen frame; for video the live screen shows through.
        Image {
            id: frozen
            anchors.fill: parent
            visible: Capture.kind !== "video"
            source: root.open ? Capture.frozen(root.screen.name) + "?" + Capture.frozenStamp : ""
            cache: false
            smooth: true
            fillMode: Image.Stretch
        }

        // Crops come from here: the frozen frame, clipped to the selection.
        Item {
            id: cropper
            x: root.sel ? root.sel.x : 0; y: root.sel ? root.sel.y : 0
            width: root.sel ? Math.max(1, root.sel.w) : 1; height: root.sel ? Math.max(1, root.sel.h) : 1
            clip: true
            z: -1
            Image { x: -cropper.x; y: -cropper.y; width: root.width; height: root.height; source: frozen.source; cache: false; smooth: true }
        }

        // Dim outside the selection (everything when there is none).
        readonly property color dim: Colors.alpha("#000000", 0.38)
        Rectangle { color: content.dim; x: 0; y: 0; width: parent.width; height: root.hasSel ? root.sel.y : parent.height }
        Rectangle { visible: root.hasSel; color: content.dim; x: 0; y: root.sel ? root.sel.y + root.sel.h : 0; width: parent.width; height: root.sel ? parent.height - root.sel.y - root.sel.h : 0 }
        Rectangle { visible: root.hasSel; color: content.dim; x: 0; y: root.sel ? root.sel.y : 0; width: root.sel ? root.sel.x : 0; height: root.sel ? root.sel.h : 0 }
        Rectangle { visible: root.hasSel; color: content.dim; x: root.sel ? root.sel.x + root.sel.w : 0; y: root.sel ? root.sel.y : 0; width: root.sel ? parent.width - root.sel.x - root.sel.w : 0; height: root.sel ? root.sel.h : 0 }

        // Screen mode: the screen under the pointer lights up.
        Rectangle {
            anchors.fill: parent
            visible: Capture.mode === "screen" && area.containsMouse
            color: Colors.alpha(Colors.accent, 0.10)
            border.width: 3; border.color: Colors.accent
        }

        // Pressing outside the selection starts a new one; inside moves it; handles resize.
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Capture.mode === "area" ? Qt.CrossCursor : Qt.PointingHandCursor
            property real x0: 0; property real y0: 0
            property string handle: ""
            property var start: null
            onPressed: m => {
                if (!root.focused_) keys.forceActiveFocus();
                x0 = m.x; y0 = m.y;
                if (Capture.mode !== "area") return;
                handle = root.hasSel ? root.hitHandle(m.x, m.y) : "";
                start = root.sel;
                if (!handle) { root.sel = Lib.normRect(m.x, m.y, m.x, m.y, root.bounds); Capture.selectionClaimed(root.screen.name); }
            }
            onPositionChanged: m => {
                if (!pressed || Capture.mode !== "area") return;
                root.sel = handle ? Lib.resize(start, handle, m.x - x0, m.y - y0, root.bounds)
                                  : Lib.normRect(x0, y0, m.x, m.y, root.bounds);
            }
            onReleased: m => {
                if (Capture.mode === "screen") { root.take(); return; }
                if (Capture.mode === "window") { root.take(); return; }
                if (!root.hasSel) { root.sel = null; return; }
                if (Capture.immediate) root.take();
            }
        }

        // The selection: accent outline, corner and edge handles, size label.
        Item {
            id: selView
            visible: root.hasSel
            x: root.sel ? root.sel.x : 0; y: root.sel ? root.sel.y : 0
            width: root.sel ? root.sel.w : 0; height: root.sel ? root.sel.h : 0
            Rectangle { anchors.fill: parent; anchors.margins: -1; color: "transparent"; border.width: 2; border.color: Colors.accent; radius: 2 }
            Repeater {
                model: Capture.immediate ? [] : ["tl", "t", "tr", "r", "br", "b", "bl", "l"]
                delegate: Rectangle {
                    required property string modelData
                    width: 10; height: 10; radius: 5
                    color: "white"; border.width: 2; border.color: Colors.accent
                    x: (modelData.indexOf("l") >= 0 ? 0 : modelData.indexOf("r") >= 0 ? selView.width : selView.width / 2) - 5
                    y: (modelData.indexOf("t") >= 0 ? 0 : modelData.indexOf("b") >= 0 ? selView.height : selView.height / 2) - 5
                }
            }
            Surface {
                group: "overlay"; level: 1; outlined: false
                width: sizeText.implicitWidth + 2 * Tokens.padding; height: Tokens.islandHeight * 0.9; radius: height / 2
                x: Math.min(root.width - width, Math.max(0, (parent.width - width) / 2))
                y: parent.y > height + Tokens.gap * 2 ? -height - Tokens.gap : parent.height + Tokens.gap
                Label { id: sizeText; anchors.centerIn: parent; numeric: true; size: Tokens.textSmall
                        text: root.sel ? Lib.sizeLabel(root.sel, root.scale_) : "" }
            }
        }

        // ------------------------------------------------------- toolbar ---
        Surface {
            id: bar
            visible: root.focused_ && !Capture.immediate
            group: "overlay"
            radius: height / 2
            width: tools.implicitWidth + 2 * Tokens.padding
            height: Tokens.islandHeight * 1.5
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - height - Tokens.islandHeight * 2.5
            scale: root.open ? 1 : 0.9
            Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.bouncy } }
            MouseArea { anchors.fill: parent }   // the toolbar is not part of the selection area
            Row {
                id: tools
                anchors.centerIn: parent
                spacing: Tokens.gap
                Segment { options: [{ v: "area", icon: "area", tip: "Area" }, { v: "window", icon: "window", tip: "Focused window" }, { v: "screen", icon: "screen", tip: "Screen" }]
                          value: Capture.mode; onPicked: v => Capture.mode = v }
                Divider {}
                Segment { options: [{ v: "photo", icon: "camera", tip: "Screenshot" }, { v: "video", icon: "video", tip: "Record" }, { v: "ocr", icon: "ocr", tip: "Copy text" }]
                          value: Capture.kind; onPicked: v => Capture.kind = v }
                Divider {}
                ToolButton { icon: "timer"; text: Capture.delay ? Capture.delay + "s" : ""; active: Capture.delay > 0; onClicked: root.cycleDelay() }
                // Recording: the computer's sound and the microphone, each a switch (remembered).
                Divider { visible: Capture.kind === "video" }
                ToolButton { visible: Capture.kind === "video"; icon: "volume-high"; active: Settings.get("capture.audio", true)
                             onClicked: Settings.set("capture.audio", !Settings.get("capture.audio", true)) }
                ToolButton { visible: Capture.kind === "video"; icon: Settings.get("capture.mic", false) ? "mic" : "mic-off"; active: Settings.get("capture.mic", false)
                             onClicked: Settings.set("capture.mic", !Settings.get("capture.mic", false)) }
                Divider {}
                ToolButton { icon: Capture.kind === "video" ? "recording" : "check"; accent: true; enabled_: Capture.mode !== "area" || root.hasSel; onClicked: root.take() }
                ToolButton { icon: "close"; onClicked: Capture.cancel() }
            }
        }

        // Hint while nothing is selected.
        Surface {
            visible: root.focused_ && Capture.mode === "area" && !root.hasSel && !area.pressed
            group: "overlay"; level: 1; outlined: false
            width: hint.implicitWidth + 2 * Tokens.padding; height: Tokens.islandHeight; radius: height / 2
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.12
            Label { id: hint; anchors.centerIn: parent; role: "dim"
                    text: Capture.kind === "ocr" ? "Drag over the text to copy it" : Capture.kind === "video" ? "Drag the area to record" : "Drag to select · Esc to cancel" }
        }
    }

    Item {
        id: keys
        focus: root.open && root.focused_
        Keys.onPressed: e => {
            const k = e.key;
            if (k === Qt.Key_Escape) Capture.cancel();
            else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.take();
            else if (k === Qt.Key_1) Capture.mode = "area";
            else if (k === Qt.Key_2) Capture.mode = "window";
            else if (k === Qt.Key_3) Capture.mode = "screen";
            else if (k === Qt.Key_P) Capture.kind = "photo";
            else if (k === Qt.Key_V) Capture.kind = "video";
            else if (k === Qt.Key_T) Capture.kind = "ocr";
            else if (k === Qt.Key_D) root.cycleDelay();
            else return;
            e.accepted = true;
        }
    }

    function cycleDelay() { Capture.delay = Capture.delay === 0 ? 3 : Capture.delay === 3 ? 5 : 0; }

    // Which handle (or "move") a press inside the selection grabbed.
    function hitHandle(x, y) {
        const s = sel, g = 10;
        const l = Math.abs(x - s.x) < g, r = Math.abs(x - (s.x + s.w)) < g;
        const t = Math.abs(y - s.y) < g, b = Math.abs(y - (s.y + s.h)) < g;
        const inX = x > s.x - g && x < s.x + s.w + g, inY = y > s.y - g && y < s.y + s.h + g;
        if (!inX || !inY) return "";
        const h = (t ? "t" : b ? "b" : "") + (l ? "l" : r ? "r" : "");
        if (h) return h;
        return (x > s.x && x < s.x + s.w && y > s.y && y < s.y + s.h) ? "move" : "";
    }

    /// Take what is selected: this screen's selection, the focused window, or this screen.
    function take() {
        const origin = { x: screen.x, y: screen.y };
        if (Capture.mode === "window") {
            if (Capture.delay > 0 || Capture.kind === "video") { Capture.later({ what: "window", screen: screen.name, rect: null, origin: origin }); return; }
            Capture.shootWindow();
            return;
        }
        const rect = Capture.mode === "area" ? (hasSel ? sel : null) : null;
        if (Capture.mode === "area" && !rect) return;
        if (Capture.kind === "video" || Capture.delay > 0) {
            Capture.later({ what: Capture.mode, screen: screen.name, rect: rect, origin: origin });
            return;
        }
        if (!rect) { Capture.shootScreen(screen.name); return; }
        const path = Capture.kind === "ocr" ? Capture.ocrPath() : Capture.newPath("photo");
        const r = rect;
        cropper.grabToImage(res => {
            if (res.saveToFile(path)) Capture.saved(path);
            else Capture.failed("Could not save " + path);
        }, Qt.size(Math.round(r.w * scale_), Math.round(r.h * scale_)));
    }

    // ------------------------------------------------------- components ---

    component Divider: Rectangle { width: 1; height: Tokens.islandHeight * 0.8; color: Colors.alpha(Colors.text, 0.15); anchors.verticalCenter: parent.verticalCenter }

    component ToolButton: Rectangle {
        id: tb
        property string icon: ""
        property string text: ""
        property bool active: false
        property bool accent: false
        property bool enabled_: true
        signal clicked()
        anchors.verticalCenter: parent.verticalCenter
        height: Tokens.islandHeight * 1.1
        width: Math.max(height, tbRow.implicitWidth + Tokens.padding * 1.5)
        radius: height / 2
        opacity: enabled_ ? 1 : 0.4
        color: accent ? Colors.accent : active ? Colors.alpha(Colors.accent, 0.25) : tbMouse.containsMouse ? Colors.alpha(Colors.text, 0.1) : "transparent"
        Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
        Row {
            id: tbRow
            anchors.centerIn: parent
            spacing: 4
            Icon { name: tb.icon; color: tb.accent ? Colors.onAccent : Colors.text; anchors.verticalCenter: parent.verticalCenter }
            Label { visible: tb.text.length > 0; text: tb.text; numeric: true; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: tbMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (tb.enabled_) tb.clicked() }
    }

    // A segmented control: one capsule, a sliding highlight under the chosen option.
    component Segment: Rectangle {
        id: seg
        property var options: []
        property string value: ""
        signal picked(string v)
        readonly property real cell: Tokens.islandHeight * 1.1
        readonly property int current: Math.max(0, options.findIndex(o => o.v === value))
        anchors.verticalCenter: parent.verticalCenter
        width: cell * options.length; height: cell; radius: height / 2
        color: Colors.alpha(Colors.text, 0.06)
        Rectangle {
            width: seg.cell; height: seg.cell; radius: height / 2
            x: seg.current * seg.cell
            color: Colors.accent
            Behavior on x { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
        }
        Row {
            Repeater {
                model: seg.options
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: seg.cell; height: seg.cell
                    Icon { anchors.centerIn: parent; name: modelData.icon; color: index === seg.current ? Colors.onAccent : Colors.text
                           Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: seg.picked(modelData.v) }
                }
            }
        }
    }
}
