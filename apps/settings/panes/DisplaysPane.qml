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
    subtitle: "Resolution, refresh rate and scale, per screen. Saved to ~/.config/vitrum/niri/displays.kdl; niri applies it at once."
    property var outs: []
    property var edits: ({})          // name → { mode, scale, vrr }
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
        const list = Object.keys(edits).map(n => Object.assign({ name: n }, edits[n]));
        saved.setText(JSON.stringify(edits, null, 2) + "\n");
        out.setText(D.outputsKdl(list));
        dirty = false;
    }

    Label { visible: page.outs.length === 0; text: page.gaveUp ? "niri did not answer (is this a vitrum session?)." : "Reading the screens…"; role: "dim" }
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
            SettingRow {
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
                label: "Scale"; divider: !D.vrrSupported(sec.modelData)
                Repeater {
                    model: [1, 1.25, 1.5, 1.75, 2]
                    delegate: Rectangle {
                        required property real modelData
                        readonly property bool on: Math.abs((sec.e.scale || D.scaleOf(sec.modelData)) - modelData) < 0.01
                        height: Tokens.islandHeight; radius: height / 2; width: sl.implicitWidth + Tokens.padding
                        color: on ? Colors.accent : Colors.alpha(Colors.text, 0.06)
                        Label { id: sl; anchors.centerIn: parent; text: Math.round(modelData * 100) + "%"; role: parent.on ? "onAccent" : "text"; size: Tokens.textSmall; numeric: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.edit(sec.modelData.name, { scale: modelData }) }
                    }
                }
            }
            // Variable refresh rate, where the screen can do it: always, or only
            // while a game is on screen (games ask for it themselves).
            SettingRow {
                visible: D.vrrSupported(sec.modelData)
                label: "Variable refresh rate"; divider: false
                Repeater {
                    model: [{ v: "off", t: "Off" }, { v: "on-demand", t: "In games" }, { v: "on", t: "Always" }]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool on: (sec.e.vrr || "off") === modelData.v
                        height: Tokens.islandHeight; radius: height / 2; width: vl.implicitWidth + Tokens.padding
                        color: on ? Colors.accent : Colors.alpha(Colors.text, 0.06)
                        Label { id: vl; anchors.centerIn: parent; text: modelData.t; role: parent.on ? "onAccent" : "text"; size: Tokens.textSmall }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.edit(sec.modelData.name, { vrr: modelData.v }) }
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
    Row {
        visible: revert.running
        spacing: Tokens.gap
        Label { text: "Keep these settings? Going back in " + page.secondsLeft + " s."; anchors.verticalCenter: parent.verticalCenter }
        Rectangle {
            height: Tokens.islandHeight * 1.2; radius: height / 2; width: kl.implicitWidth + Tokens.padding * 2; color: Colors.accent
            Label { id: kl; anchors.centerIn: parent; text: "Keep"; role: "onAccent"; font.weight: Font.DemiBold }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: revert.stop() }
        }
        Rectangle {
            height: Tokens.islandHeight * 1.2; radius: height / 2; width: rl.implicitWidth + Tokens.padding * 2; color: Colors.alpha(Colors.text, 0.06)
            Label { id: rl; anchors.centerIn: parent; text: "Go back" }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { revert.stop(); page.edits = page.before; page.save(true); } }
        }
    }
    Rectangle {
        visible: page.dirty && !revert.running
        height: Tokens.islandHeight * 1.2; radius: height / 2; width: al.implicitWidth + Tokens.padding * 2
        color: Colors.accent
        Label { id: al; anchors.centerIn: parent; text: "Apply"; role: "onAccent"; font.weight: Font.DemiBold }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.save() }
    }
    }
    // A choice chip: the picked one in the accent.
    component Chip_: Rectangle {
        id: chip
        property string text: ""
        property bool on: false
        signal picked()
        height: Tokens.islandHeight; radius: height / 2; width: cl.implicitWidth + Tokens.padding * 1.2
        color: on ? Colors.accent : Colors.alpha(Colors.text, cm.containsMouse ? 0.1 : 0.06)
        Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
        Label { id: cl; anchors.centerIn: parent; text: chip.text; role: chip.on ? "onAccent" : "text"; size: Tokens.textSmall; numeric: true }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.picked() }
    }
}
