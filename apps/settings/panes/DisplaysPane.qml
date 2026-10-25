import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import qs.common
import "../lib/displays.js" as D

Page {
    id: page
    title: "Displays"
    subtitle: "Where the screens sit, and each one's resolution, refresh rate, scale and rotation. Saved to ~/.config/vitrum/niri/displays.kdl; niri applies it at once."
    property var outs: []
    property var edits: ({})          // name → { mode, scale, vrr, transform, position, off, primary, mirror }
    readonly property string file: Quickshell.env("HOME") + "/.config/vitrum/niri/displays.kdl"

    // niri can be slow to answer while busy: retried a few times before saying so.
    property int tries: 0
    property bool gaveUp: false
    Process {
        id: ask
        running: true
        command: [Niri.bin, "msg", "--json", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: { try { const o = JSON.parse(text); page.outs = Object.keys(o).map(k => Object.assign({ name: k }, o[k])); } catch (e) { page.outs = []; } }
        }
        onExited: if (page.outs.length === 0) { if (++page.tries < 4) retry.restart(); else page.gaveUp = true; }
    }
    Timer { id: retry; interval: 800; onTriggered: ask.running = true }
    FileView { id: out; path: page.file; blockLoading: false }
    // What was set before (any session), kept beside the KDL so a new change keeps the old ones.
    FileView {
        id: saved
        path: page.file.replace(/\.kdl$/, ".json")
        onLoaded: { try { page.edits = JSON.parse(text()) || {}; } catch (e) { page.edits = {}; } }
    }
    property bool dirty: false

    function edit(name, patch) { const e = Object.assign({}, edits); e[name] = Object.assign({}, e[name] || {}, patch); edits = e; dirty = true; }
    // A mode that leaves the screen dark must not stick: unless kept within
    // 15 s, the previous settings come back.
    property var before: ({})
    property int secondsLeft: 0
    Timer { id: revert; interval: 1000; repeat: true; onTriggered: { if (--page.secondsLeft <= 0) { stop(); page.edits = page.before; page.save(true); } } }
    function save(restoring) {
        if (!restoring) { before = JSON.parse(saved.text() || "{}"); secondsLeft = 15; revert.restart(); }
        // A screen that is off or shows another one has no place in the layout.
        const list = Object.keys(edits).map(n => {
            const o = Object.assign({ name: n }, edits[n]);
            if (o.off || o.mirror) delete o.position;
            return o;
        });
        saved.setText(JSON.stringify(edits, null, 2) + "\n");
        out.setText(D.outputsKdl(list));
        dirty = false;
        reread.restart();
    }
    // What niri made of it (a mode it could not do, a scale it rounded).
    Timer { id: reread; interval: 1200; onTriggered: { page.tries = 0; ask.running = true; } }

    // The screens as they are or as chosen: on, not showing another one.
    function isOff(o) { const e = edits[o.name] || {}; return e.off !== undefined ? e.off : o.current_mode === null || o.current_mode === undefined; }
    function mirrorOf(o) { const e = edits[o.name] || {}; return e.mirror || ""; }
    readonly property var placed: outs.filter(o => !isOff(o) && !mirrorOf(o))
    // Their rectangles in the layout (logical pixels): positions chosen, else niri's.
    readonly property var layout: placed.map(o => {
        const e = edits[o.name] || {}, sz = D.logicalSize(o, e);
        const p = e.position || (o.logical ? { x: o.logical.x, y: o.logical.y } : { x: 0, y: 0 });
        return { name: o.name, x: p.x, y: p.y, w: sz.w, h: sz.h };
    })
    // A screen dropped at (x, y): against its neighbours, every position written.
    function place(name, x, y) {
        const rects = layout.map(r => ({ x: r.x, y: r.y, w: r.w, h: r.h }));
        const i = layout.findIndex(r => r.name === name);
        if (i < 0) return;
        const p = D.snap(rects, i, x, y);
        rects[i].x = p.x; rects[i].y = p.y;
        const n = D.normalize(rects), e = Object.assign({}, edits);
        layout.forEach((r, k) => { e[r.name] = Object.assign({}, e[r.name] || {}, { position: { x: n[k].x, y: n[k].y } }); });
        edits = e; dirty = true;
    }
    function setPrimary(name) {
        const e = Object.assign({}, edits);
        outs.forEach(o => { e[o.name] = Object.assign({}, e[o.name] || {}, { primary: o.name === name }); });
        edits = e; dirty = true;
    }

    Label { visible: page.outs.length === 0; text: page.gaveUp ? "niri did not answer (is this a vitrum session?)." : "Reading the screens…"; role: "dim" }
    Section {
        title: "Arrangement"
        visible: page.outs.length > 1
        note: "Drag a screen to where it stands on your desk; it settles against the others. The star marks the main screen, where the session starts."
        Item {
            id: canvas
            width: parent.width
            height: Tokens.islandHeight * 9
            readonly property real pad: Tokens.padding * 1.5
            readonly property real minX: page.layout.length ? Math.min(...page.layout.map(r => r.x)) : 0
            readonly property real minY: page.layout.length ? Math.min(...page.layout.map(r => r.y)) : 0
            readonly property real spanW: page.layout.length ? Math.max(...page.layout.map(r => r.x + r.w)) - minX : 1
            readonly property real spanH: page.layout.length ? Math.max(...page.layout.map(r => r.y + r.h)) - minY : 1
            // Room around the layout to drop a screen beside it.
            readonly property real k: Math.min((width - pad * 2) / (spanW * 1.6), (height - pad * 2) / (spanH * 1.6))
            readonly property real offX: (width - spanW * k) / 2
            readonly property real offY: (height - spanH * k) / 2
            Repeater {
                model: page.layout
                // A screen: a pane of tinted glass, ringed in the accent while held.
                delegate: Item {
                    id: scr
                    required property var modelData
                    property real dx: 0
                    property real dy: 0
                    readonly property bool primary: !!(page.edits[modelData.name] || {}).primary
                    x: canvas.offX + (modelData.x - canvas.minX) * canvas.k + dx
                    y: canvas.offY + (modelData.y - canvas.minY) * canvas.k + dy
                    width: modelData.w * canvas.k - 3
                    height: modelData.h * canvas.k - 3
                    z: drag.pressed ? 2 : 1
                    Behavior on x { enabled: Motion.enabled && !drag.pressed; SpringAnim { token: Motion.smooth } }
                    Behavior on y { enabled: Motion.enabled && !drag.pressed; SpringAnim { token: Motion.smooth } }
                    Surface { anchors.fill: parent; group: "panels"; level: 1; radius: Tokens.radiusButton }
                    ShellTint { anchors.fill: parent; radius: Tokens.radiusButton; hovered: drag.containsMouse }
                    Rectangle {
                        anchors.fill: parent; radius: Tokens.radiusButton
                        color: "transparent"
                        border.width: 2; border.color: Colors.accent
                        opacity: drag.pressed ? 1 : 0
                        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
                    }
                    Column {
                        anchors.centerIn: parent
                        width: parent.width - Tokens.gap
                        Icon { visible: scr.primary; name: "star"; color: Colors.text; anchors.horizontalCenter: parent.horizontalCenter; size: Tokens.iconSize * 0.9 }
                        Label { text: scr.modelData.name; width: parent.width; horizontalAlignment: Text.AlignHCenter; font.weight: Font.DemiBold; size: Tokens.textSmall + 1 }
                        Label { text: scr.modelData.w + " × " + scr.modelData.h; width: parent.width; horizontalAlignment: Text.AlignHCenter; role: "dim"; size: Tokens.textSmall; numeric: true }
                    }
                    MouseArea {
                        id: drag
                        anchors.fill: parent
                        hoverEnabled: true
                        // The page scrolls: a vertical drag here is the screen's, not the page's.
                        preventStealing: true
                        onCanceled: { scr.dx = 0; scr.dy = 0; }
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        property point start
                        onPressed: m => start = mapToItem(canvas, m.x, m.y)
                        onPositionChanged: m => { if (!pressed) return; const p = mapToItem(canvas, m.x, m.y); scr.dx = p.x - start.x; scr.dy = p.y - start.y; }
                        onReleased: {
                            const moved = Math.abs(scr.dx) + Math.abs(scr.dy) > 4;
                            const nx = scr.modelData.x + scr.dx / canvas.k, ny = scr.modelData.y + scr.dy / canvas.k;
                            scr.dx = 0; scr.dy = 0;
                            if (moved) page.place(scr.modelData.name, nx, ny);
                        }
                        onDoubleClicked: page.setPrimary(scr.modelData.name)
                    }
                }
            }
        }
    }
    Repeater {
        model: page.outs
        delegate: Section {
            id: sec
            required property var modelData
            readonly property var e: page.edits[modelData.name] || {}
            readonly property var modes: D.modes(modelData)
            title: modelData.name + (modelData.make ? " · " + modelData.make + " " + (modelData.model || "") : "")
            // The mode in use or chosen, as a size and a rate apart.
            readonly property string mode: sec.e.mode || sec.modes[0] || ""
            readonly property string res: mode.split("@")[0]
            readonly property int hz: Math.round(Number(mode.split("@")[1] || 0))
            // The usual sizes first; the odd ones (4:3 on a wide screen, 640 × 480) behind More.
            property bool allSizes: false
            readonly property var sizes: allSizes ? D.resolutions(modelData) : D.usualResolutions(modelData, res)
            readonly property bool moreSizes: D.resolutions(modelData).length > D.usualResolutions(modelData, res).length
            readonly property bool off: page.isOff(modelData)
            readonly property string mirror: page.mirrorOf(modelData)
            readonly property bool on_: !off && !mirror
            SettingRow {
                label: "Use this screen"
                hint: sec.mirror ? "Showing the same picture as " + sec.mirror : ""
                GlassSwitch {
                    checked: !sec.off
                    // Never the last screen that is on.
                    opacity: !sec.off && page.outs.filter(o => !page.isOff(o)).length < 2 ? 0.4 : 1
                    onToggled: if (sec.off || page.outs.filter(o => !page.isOff(o)).length > 1) page.edit(sec.modelData.name, { off: !sec.off })
                }
            }
            SettingRow {
                visible: !sec.off && page.outs.length > 1
                label: "Mirror"
                hint: "Show another screen's picture here instead of its own desktop"
                Repeater {
                    model: [""].concat(page.outs.filter(o => o.name !== sec.modelData.name && !page.isOff(o) && !page.mirrorOf(o)).map(o => o.name))
                    delegate: Chip_ {
                        required property string modelData
                        text: modelData || "Off"
                        on: sec.mirror === modelData
                        onPicked: page.edit(sec.modelData.name, { mirror: modelData, primary: modelData ? false : (page.edits[sec.modelData.name] || {}).primary })
                    }
                }
            }
            SettingRow {
                visible: sec.on_ && page.outs.length > 1
                label: "Main screen"; hint: "Where the session starts and new windows go first"
                GlassSwitch { checked: !!sec.e.primary; onToggled: page.setPrimary(sec.e.primary ? "" : sec.modelData.name) }
            }
            SettingRow {
                visible: !sec.off
                label: "Resolution"
                Flow {
                    width: Math.min(implicitRowWidth, Tokens.islandHeight * 15)
                    // One line when it fits: the chips' own width, so the row stays flush right.
                    readonly property real implicitRowWidth: {
                        let w = 0;
                        for (let i = 0; i < children.length; i++) if (children[i].visible && children[i].width) w += children[i].width + spacing;
                        return Math.max(1, w - spacing);
                    }
                    spacing: 4
                    Repeater {
                        model: sec.sizes
                        delegate: Chip_ {
                            required property string modelData
                            text: modelData.replace("x", " × ")
                            on: sec.res === modelData
                            onPicked: page.edit(sec.modelData.name, { mode: D.pick(sec.modelData, modelData, sec.hz) })
                        }
                    }
                    Chip_ {
                        visible: sec.moreSizes
                        text: sec.allSizes ? "Fewer" : "More…"
                        onPicked: sec.allSizes = !sec.allSizes
                    }
                }
            }
            SettingRow {
                visible: !sec.off
                label: "Refresh rate"
                Repeater {
                    model: D.rates(sec.modelData, sec.res)
                    delegate: Chip_ {
                        required property var modelData
                        text: modelData.hz + " Hz"
                        on: sec.hz === modelData.hz
                        onPicked: page.edit(sec.modelData.name, { mode: modelData.mode })
                    }
                }
            }
            SettingRow {
                id: rotRow
                visible: sec.on_
                label: "Rotation"
                readonly property string rot: D.rotationOf(sec.modelData, sec.e)
                hint: rot ? "" : "Mirrored now (" + (sec.e.transform || D.transformOf(sec.modelData)) + "). A choice here turns it without the mirror."
                Repeater {
                    model: [{ v: "normal", t: "Normal" }, { v: "90", t: "90°" }, { v: "180", t: "180°" }, { v: "270", t: "270°" }]
                    delegate: Chip_ {
                        required property var modelData
                        text: modelData.t
                        on: rotRow.rot === modelData.v
                        onPicked: page.edit(sec.modelData.name, { transform: modelData.v })
                    }
                }
            }
            SettingRow {
                visible: sec.on_
                label: "Scale"; divider: !D.vrrSupported(sec.modelData)
                Repeater {
                    model: [1, 1.25, 1.5, 1.75, 2]
                    delegate: Chip_ {
                        required property real modelData
                        text: Math.round(modelData * 100) + "%"
                        on: Math.abs((sec.e.scale || D.scaleOf(sec.modelData)) - modelData) < 0.01
                        onPicked: page.edit(sec.modelData.name, { scale: modelData })
                    }
                }
            }
            // Variable refresh rate, where the screen can do it: always, or only
            // while a game is on screen (games ask for it themselves).
            SettingRow {
                visible: D.vrrSupported(sec.modelData) && !sec.off
                label: "Variable refresh rate"; divider: false
                Repeater {
                    model: [{ v: "off", t: "Off" }, { v: "on-demand", t: "In games" }, { v: "on", t: "Always" }]
                    delegate: Chip_ {
                        required property var modelData
                        text: modelData.t
                        on: (sec.e.vrr || "off") === modelData.v
                        onPicked: page.edit(sec.modelData.name, { vrr: modelData.v })
                    }
                }
            }
        }
    }
    Section {
        title: "Brightness"
        visible: Power.hasBacklight
        SettingRow {
            label: "Screen brightness"; divider: false
            Slider { width: Tokens.islandHeight * 8; value: Power.brightness; icon: "brightness"; onMoved: v => Power.setBrightness(v) }
        }
    }
    Row {
        visible: revert.running
        spacing: Tokens.gap
        Label { text: "Keep these settings? Going back in " + page.secondsLeft + " s."; anchors.verticalCenter: parent.verticalCenter }
        GlassButton { label: "Keep"; primary: true; height: Tokens.islandHeight * 1.2; onClicked: revert.stop() }
        GlassButton { label: "Go back"; height: Tokens.islandHeight * 1.2; onClicked: { revert.stop(); page.edits = page.before; page.save(true); } }
    }
    GlassButton {
        visible: page.dirty && !revert.running
        label: "Apply"; primary: true; height: Tokens.islandHeight * 1.2
        onClicked: page.save()
    }
    // A choice chip on glass: the picked one tinted.
    component Chip_: Item {
        id: chip
        property string text: ""
        property bool on: false
        signal picked()
        height: Tokens.islandHeight; width: cl.implicitWidth + Tokens.padding * 1.2
        Surface { anchors.fill: parent; group: "panels"; level: 1; radius: Tokens.radiusTile }
        // The lift under the pointer, on clear glass.
        Rectangle {
            anchors.fill: parent; radius: Tokens.radiusTile
            color: Colors.alpha(Colors.text, !chip.on && cm.containsMouse ? 0.06 : 0)
            Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
        }
        ShellTint { anchors.fill: parent; radius: Tokens.radiusTile; active: chip.on; hovered: cm.containsMouse }
        Label { id: cl; anchors.centerIn: parent; text: chip.text; size: Tokens.textSmall; numeric: true }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.picked() }
    }
}
