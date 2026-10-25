import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components

/*
 * The colour picker's history (picker.history, newest first) as round
 * swatches, each with its hex under it.
 *   S   the newest three, two by two, the picker's key in the fourth place
 *   M   the header, the picker's key at its end; the newest five in a row
 * A click copies the hex (the history keeps its order): the swatch's rim
 * lights up and its label says so for a moment. A swatch lifts under the
 * pointer. The key starts the picker (as `vitrum-ipc picker start`).
 * options: upper (hex in capitals).
 * In a gallery card, sample colours; nothing is copied or picked.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    readonly property bool small: sizeClass === "S"
    readonly property var sample: ["#7aa2f7", "#e0af68", "#9ece6a", "#f7768e", "#bb9af7", "#2ac3de"]
    readonly property var history: (preview ? sample : ColorPick.history).filter(h => /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(String(h)))
    readonly property int slots: small ? 3 : 5
    readonly property var shown: history.slice(0, slots)
    function label(h) { return options.upper === false ? String(h).toLowerCase() : String(h).toUpperCase(); }

    property string copied: ""
    Timer { id: unlight; interval: 1400; onTriggered: root.copied = "" }
    function copy(hex) {
        if (preview) return;
        Quickshell.execDetached(["wl-copy", "--", hex]);
        copied = hex;
        unlight.restart();
    }
    function pick() { if (!preview) ColorPick.start(); }

    // A swatch: the colour as a round bead of glass — a hairline rim, a soft
    // highlight across its top — and its hex under it.
    component Swatch: Item {
        id: sw
        property string hex: ""
        property real d: 32
        readonly property bool lit: root.copied === hex
        width: d * 1.7; height: d + Tokens.textSmall + Math.round(Tokens.gap * 0.5)
        Item {
            id: bead
            anchors.horizontalCenter: parent.horizontalCenter
            width: sw.d; height: sw.d
            scale: mouse.pressed ? 0.94 : mouse.containsMouse ? 1.08 : 1
            Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }
            // The light when copied: a lit ring just outside the bead.
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 2 * Math.round(Tokens.gap * 0.35); height: width; radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: Colors.alpha(Colors.accent, sw.lit ? 0.9 : 0)
                Behavior on border.color { enabled: Motion.enabled; ColorAnim {} }
            }
            Rectangle {
                anchors.fill: parent; radius: width / 2
                color: sw.hex || "transparent"
                border.width: Tokens.hairline
                border.color: Colors.alpha(Colors.text, 0.22)
            }
            Rectangle {
                anchors.fill: parent; radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.34) }
                    GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0) }
                }
            }
        }
        Label {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: sw.lit ? "Copied" : root.label(sw.hex)
            role: sw.lit ? "accent" : "dim"
            size: Tokens.textSmall; numeric: true
            elide: Text.ElideNone
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            enabled: !root.preview
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.copy(sw.hex)
        }
    }

    WidgetHeader {
        id: head
        visible: !root.small
        height: visible ? implicitHeight : 0
        icon: "palette"; title: "Colours"
    }
    GlassButton {
        visible: !root.small
        anchors { right: parent.right; verticalCenter: head.verticalCenter }
        height: head.height; width: height
        group: "widgets"
        icon: "colorize"
        enabled: !root.preview
        onClicked: root.pick()
    }
    WidgetEmpty {
        visible: root.history.length === 0 && !root.small
        anchors.verticalCenterOffset: head.height / 2
        icon: "colorize"
        text: "Pick a colour from the screen"
    }

    // ---- S: two by two, the picker's key last.
    Grid {
        visible: root.small
        anchors.centerIn: parent
        columns: 2
        rowSpacing: Math.round(Tokens.gap * 0.4)
        readonly property real d: Math.round(Math.min(root.width, root.height) * 0.27)
        Repeater {
            model: root.small ? root.shown : []
            delegate: Swatch { required property string modelData; hex: modelData; d: parent.d }
        }
        // The picker's key: a bead of clear glass with the eyedropper, in the same place a swatch would be.
        Item {
            width: parent.d * 1.7; height: parent.d + Tokens.textSmall + Math.round(Tokens.gap * 0.5)
            GlassButton {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.parent.d; height: width
                radius: width / 2
                group: "widgets"
                icon: "colorize"
                enabled: !root.preview
                onClicked: root.pick()
            }
            Label {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                text: "Pick"
                role: "dim"; size: Tokens.textSmall
            }
        }
    }

    // ---- M: one row under the header.
    Row {
        visible: !root.small && root.shown.length > 0
        anchors { horizontalCenter: parent.horizontalCenter; top: head.bottom; bottom: parent.bottom; topMargin: Tokens.gap * 0.5 }
        readonly property real cellW: root.width / root.slots
        readonly property real d: Math.round(Math.min(cellW / 1.7, height - Tokens.textSmall - Tokens.gap) * 0.95)
        Repeater {
            model: root.small ? [] : root.shown
            delegate: Item {
                required property string modelData
                width: parent.cellW; height: parent.height
                Swatch { anchors.centerIn: parent; hex: parent.modelData; d: parent.parent.d }
            }
        }
    }
}
