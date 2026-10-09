import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.components

/*
 * The screenshot editor: arrows, boxes, text, a marker, blur and crop, on the
 * picture just taken (click its thumbnail). Copy puts the result on the
 * clipboard, Save writes it over the file. Ctrl+Z undoes, Esc closes.
 *
 * The picture is edited at its own size ("doc", scaled to fit the screen), so
 * what is saved is pixel for pixel what was shot plus the marks.
 */
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property bool open: Capture.editing !== "" && modelData.name === (Niri.focusedOutput || Quickshell.screens[0].name)
    // Mapped only while editing (MapGate: never mid-build), full-screen and opaque-ish.
    MapGate { id: gate; want: root.open; linger: 0 }
    visible: gate.mapped
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Colors.alpha("#000000", 0.55)
    WlrLayershell.namespace: "vitrum-editor"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property string tool: "arrow"           // arrow | rect | text | marker | blur | crop
    property color ink: "#ff453a"
    property int stroke: 4
    property var marks: []                  // { kind, pts | x,y,w,h | text, color, width }
    property var draft: null
    property rect crop: Qt.rect(0, 0, 0, 0)
    readonly property bool hasCrop: crop.width > 4 && crop.height > 4

    onOpenChanged: if (open) { marks = []; draft = null; crop = Qt.rect(0, 0, 0, 0); tool = "arrow"; keys.forceActiveFocus(); }

    function undo() {
        if (draftText.visible) { draftText.visible = false; return; }
        if (hasCrop && tool === "crop") { crop = Qt.rect(0, 0, 0, 0); return; }
        marks = marks.slice(0, -1);
    }
    // The result: the doc, cropped if asked, at the picture's own size.
    function render(then) {
        commitText();
        const view = hasCrop ? cropView : doc;
        if (hasCrop) { cropView.width = crop.width; cropView.height = crop.height; }
        view.grabToImage(r => then(r), hasCrop ? Qt.size(crop.width, crop.height) : Qt.size(doc.width, doc.height));
    }
    function save() { render(r => { r.saveToFile(Capture.editing); Capture.editDone(Capture.editing, false); }); }
    function copy() {
        const tmp = Capture.runtime + "/edited.png";
        render(r => { r.saveToFile(tmp); Capture.copy(tmp); Capture.editDone("", true); });
    }

    Item {
        id: keys
        focus: root.open
        Keys.onEscapePressed: Capture.editDone("", false)
        Keys.onPressed: e => {
            if (draftText.activeFocus) return;
            const ctrl = e.modifiers & Qt.ControlModifier;
            if (ctrl && e.key === Qt.Key_Z) { root.undo(); e.accepted = true; }
            else if (ctrl && e.key === Qt.Key_C) { root.copy(); e.accepted = true; }
            else if (ctrl && e.key === Qt.Key_S) { root.save(); e.accepted = true; }
            else if (!ctrl) {
                const t = { "a": "arrow", "r": "rect", "t": "text", "m": "marker", "b": "blur", "c": "crop" }[e.text];
                if (t) { root.tool = t; e.accepted = true; }
            }
        }
    }

    // ---------------------------------------------------------- the doc ---
    Image { id: picture; source: root.open ? "file://" + Capture.editing + "?" + Capture.editStamp : ""; visible: false; cache: false }
    readonly property real fit: picture.width > 0 ? Math.min((width * 0.86) / picture.width, (height - Tokens.islandHeight * 5) / picture.height, 1.5) : 1

    Item {
        id: stage
        width: doc.width * root.fit; height: doc.height * root.fit
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Tokens.islandHeight * 1.2

        // The crop, for the result: a window onto the doc.
        // Kept far off screen: grabbed, never seen.
        Item {
            id: cropView
            x: -100000
            clip: true
            ShaderEffectSource { x: -root.crop.x; y: -root.crop.y; width: doc.width; height: doc.height; sourceItem: doc; live: true }
        }

        Item {
            id: doc
            width: picture.width; height: picture.height
            scale: root.fit
            transformOrigin: Item.TopLeft

            Image { anchors.fill: parent; source: picture.source; cache: false; smooth: true }

            // Blur: the picture under each box, blurred.
            Repeater {
                model: root.marks.filter(m => m.kind === "blur").concat(root.draft && root.draft.kind === "blur" ? [root.draft] : [])
                Item {
                    required property var modelData
                    x: modelData.x; y: modelData.y; width: modelData.w; height: modelData.h
                    clip: true
                    Image { id: under; x: -parent.x; y: -parent.y; width: doc.width; height: doc.height; source: picture.source; cache: false; visible: false }
                    MultiEffect { source: under; x: under.x; y: under.y; width: under.width; height: under.height; blurEnabled: true; blur: 1.0; blurMax: 64; autoPaddingEnabled: false }
                }
            }

            // Arrows, boxes and the marker.
            Canvas {
                id: ink
                anchors.fill: parent
                renderTarget: Canvas.Image
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const all = root.marks.concat(root.draft ? [root.draft] : []);
                    for (const m of all) {
                        ctx.strokeStyle = m.color; ctx.fillStyle = m.color; ctx.lineCap = "round"; ctx.lineJoin = "round";
                        if (m.kind === "rect") { ctx.lineWidth = m.width; ctx.strokeRect(m.x, m.y, m.w, m.h); }
                        else if (m.kind === "arrow" && m.pts.length >= 2) {
                            const a = m.pts[0], b = m.pts[m.pts.length - 1];
                            const ang = Math.atan2(b.y - a.y, b.x - a.x), head = Math.max(14, m.width * 4.5);
                            ctx.lineWidth = m.width;
                            ctx.beginPath(); ctx.moveTo(a.x, a.y);
                            ctx.lineTo(b.x - Math.cos(ang) * head * 0.6, b.y - Math.sin(ang) * head * 0.6); ctx.stroke();
                            ctx.beginPath(); ctx.moveTo(b.x, b.y);
                            ctx.lineTo(b.x - head * Math.cos(ang - 0.42), b.y - head * Math.sin(ang - 0.42));
                            ctx.lineTo(b.x - head * Math.cos(ang + 0.42), b.y - head * Math.sin(ang + 0.42));
                            ctx.closePath(); ctx.fill();
                        } else if (m.kind === "marker" && m.pts.length >= 2) {
                            ctx.globalAlpha = 0.4; ctx.lineWidth = m.width * 5;
                            ctx.beginPath(); ctx.moveTo(m.pts[0].x, m.pts[0].y);
                            for (const p of m.pts.slice(1)) ctx.lineTo(p.x, p.y);
                            ctx.stroke(); ctx.globalAlpha = 1;
                        }
                    }
                }
            }
            Connections { target: root; function onMarksChanged() { ink.requestPaint(); } function onDraftChanged() { ink.requestPaint(); } }

            // Text marks.
            Repeater {
                model: root.marks.filter(m => m.kind === "text")
                Text {
                    required property var modelData
                    x: modelData.x; y: modelData.y
                    text: modelData.text; color: modelData.color
                    font.family: Tokens.fontText; font.pixelSize: modelData.size; font.weight: Font.DemiBold
                    style: Text.Outline; styleColor: Colors.alpha("#000000", 0.35)
                }
            }
            TextInput {
                id: draftText
                visible: false
                color: root.ink
                font.family: Tokens.fontText; font.pixelSize: Math.max(18, root.stroke * 7); font.weight: Font.DemiBold
                Keys.onReturnPressed: root.commitText()
                Keys.onEscapePressed: { visible = false; keys.forceActiveFocus(); }
            }
        }

        // Drawing on the doc (pointer in doc coordinates).
        MouseArea {
            anchors.fill: parent
            cursorShape: root.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor
            function at(m) { return { x: m.x / root.fit, y: m.y / root.fit }; }
            onPressed: m => {
                const p = at(m);
                if (root.tool === "text") { root.commitText(); draftText.x = p.x; draftText.y = p.y; draftText.text = ""; draftText.visible = true; draftText.forceActiveFocus(); return; }
                root.commitText();
                if (root.tool === "arrow" || root.tool === "marker") root.draft = { kind: root.tool, pts: [p], color: root.ink.toString(), width: root.stroke };
                else root.draft = { kind: root.tool, x0: p.x, y0: p.y, x: p.x, y: p.y, w: 0, h: 0, color: root.ink.toString(), width: root.stroke };
            }
            onPositionChanged: m => {
                if (!root.draft) return;
                const p = at(m), d = Object.assign({}, root.draft);
                if (d.pts) d.pts = d.kind === "arrow" ? [d.pts[0], p] : d.pts.concat([p]);
                else { d.x = Math.min(d.x0, p.x); d.y = Math.min(d.y0, p.y); d.w = Math.abs(p.x - d.x0); d.h = Math.abs(p.y - d.y0); }
                root.draft = d;
                if (d.kind === "crop") root.crop = Qt.rect(d.x, d.y, d.w, d.h);
            }
            onReleased: {
                const d = root.draft;
                root.draft = null;
                if (!d || d.kind === "crop") return;
                if ((d.pts && d.pts.length < 2) || (!d.pts && (d.w < 3 || d.h < 3))) return;
                root.marks = root.marks.concat([d]);
            }
        }

        // The crop: everything outside it darkened.
        Item {
            anchors.fill: parent
            visible: root.hasCrop
            readonly property rect r: Qt.rect(root.crop.x * root.fit, root.crop.y * root.fit, root.crop.width * root.fit, root.crop.height * root.fit)
            Rectangle { x: 0; y: 0; width: parent.width; height: parent.r.y; color: Colors.alpha("#000000", 0.5) }
            Rectangle { x: 0; y: parent.r.y + parent.r.height; width: parent.width; height: parent.height - y; color: Colors.alpha("#000000", 0.5) }
            Rectangle { x: 0; y: parent.r.y; width: parent.r.x; height: parent.r.height; color: Colors.alpha("#000000", 0.5) }
            Rectangle { x: parent.r.x + parent.r.width; y: parent.r.y; width: parent.width - x; height: parent.r.height; color: Colors.alpha("#000000", 0.5) }
            Rectangle { x: parent.r.x; y: parent.r.y; width: parent.r.width; height: parent.r.height; color: "transparent"; border.width: 2; border.color: "white" }
        }
    }

    function commitText() {
        if (!draftText.visible) return;
        if (draftText.text.trim()) root.marks = root.marks.concat([{ kind: "text", x: draftText.x, y: draftText.y, text: draftText.text, color: root.ink.toString(), size: draftText.font.pixelSize }]);
        draftText.visible = false;
        keys.forceActiveFocus();
    }

    // ---------------------------------------------------------- toolbar ---
    Surface {
        group: "overlay"
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Tokens.islandHeight * 1.5 }
        width: bar.implicitWidth + 2 * Tokens.padding
        height: Tokens.islandHeight * 1.5
        radius: height / 2
        MouseArea { anchors.fill: parent }
        Row {
            id: bar
            anchors.centerIn: parent
            spacing: Tokens.gap / 2
            Repeater {
                model: [{ t: "arrow", i: "arrow", tip: "Arrow (A)" }, { t: "rect", i: "rect", tip: "Box (R)" }, { t: "text", i: "text", tip: "Text (T)" },
                        { t: "marker", i: "brush", tip: "Marker (M)" }, { t: "blur", i: "blur", tip: "Blur (B)" }, { t: "crop", i: "crop", tip: "Crop (C)" }]
                Capsule { required property var modelData; icon: modelData.i; active: root.tool === modelData.t; onClicked: root.tool = modelData.t }
            }
            Rectangle { width: 1; height: Tokens.islandHeight * 0.6; color: Colors.alpha(Colors.text, 0.2); anchors.verticalCenter: parent.verticalCenter }
            Repeater {
                model: ["#ff453a", "#ffd60a", "#30d158", "#0a84ff", "#ffffff", "#1c1c1e"]
                Rectangle {
                    required property string modelData
                    width: Tokens.islandHeight * 0.75; height: width; radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: modelData
                    border.width: root.ink.toString() === Qt.color(modelData).toString() ? 3 : 1
                    border.color: root.ink.toString() === Qt.color(modelData).toString() ? Colors.accent : Colors.alpha(Colors.text, 0.3)
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.ink = modelData }
                }
            }
            Capsule { label: root.stroke <= 3 ? "Thin" : root.stroke <= 5 ? "Medium" : "Thick"; onClicked: root.stroke = root.stroke <= 3 ? 5 : root.stroke <= 5 ? 8 : 3 }
            Rectangle { width: 1; height: Tokens.islandHeight * 0.6; color: Colors.alpha(Colors.text, 0.2); anchors.verticalCenter: parent.verticalCenter }
            Capsule { icon: "undo"; onClicked: root.undo() }
            Capsule { icon: "copy"; label: "Copy"; onClicked: root.copy() }
            Capsule { icon: "save"; label: "Save"; active: true; onClicked: root.save() }
            Capsule { icon: "close"; onClicked: Capture.editDone("", false) }
        }
    }
}
