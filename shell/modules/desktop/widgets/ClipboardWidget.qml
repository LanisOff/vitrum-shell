import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components
import "../../../lib/clip.js" as Lib

/*
 * The clipboard's last few entries (Clipboard: cliphist, as vitrum-clip keeps
 * it), listed again whenever something new is copied.
 *   M   the header; a row each, newest first — a text on one line, or a
 *       picture's thumbnail with its kind and size — as many as fit
 *   L   the same, with room for more
 * A click puts the entry back on the clipboard: the row lights up for a
 * moment under a check. Rows lift under the pointer.
 * options: images (pictures listed too).
 * In a gallery card, sample entries; nothing is read or copied.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    // preview is set after Component.onCompleted: subscribe a turn later, once it is known.
    property bool watching: false
    Component.onCompleted: Qt.callLater(() => { if (!root.preview) { root.watching = true; Clipboard.watch(); } })
    Component.onDestruction: if (watching) Clipboard.unwatch()

    readonly property bool images: options.images !== false
    readonly property var sample: [
        { id: "s1", preview: "https://github.com/quickshell-mirror/quickshell", isImage: false },
        { id: "s2", preview: "[[ binary data 412 KiB png 1920x1080 ]]", isImage: true, sample: true },
        { id: "s3", preview: "Meet at the station at 9:40, platform 4", isImage: false },
        { id: "s4", preview: "sudo pacman -Syu --needed base-devel", isImage: false },
        { id: "s5", preview: "#7aa2f7", isImage: false }
    ]
    readonly property var entries: (preview ? sample : Clipboard.recent).filter(e => images || !e.isImage)
    readonly property var shown: entries.slice(0, rows.fits)
    onShownChanged: if (!preview) Clipboard.wantImages(shown)

    // The row just copied, lit for a moment.
    property string copied: ""
    Timer { id: unlight; interval: 1400; onTriggered: root.copied = "" }
    function copy(e) {
        if (preview) return;
        Clipboard.copy(e);
        copied = e.id;
        unlight.restart();
    }

    WidgetHeader {
        id: head
        icon: "clipboard"; title: "Clipboard"
    }
    WidgetEmpty {
        visible: root.entries.length === 0
        icon: "clipboard"
        text: Clipboard.available ? "Nothing copied yet" : "The clipboard history needs cliphist"
    }

    Column {
        id: rows
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: Tokens.gap * 0.5; bottom: parent.bottom }
        readonly property real rowH: Math.round(Tokens.textSize * (root.sizeClass === "M" ? 2.15 : 2.6))
        readonly property int fits: Math.max(1, Math.floor((height + spacing) / (rowH + spacing)))
        spacing: Math.round(Tokens.gap * 0.3)
        Repeater {
            model: root.shown
            delegate: Item {
                id: row
                required property var modelData
                readonly property bool lit: root.copied === modelData.id
                readonly property var info: modelData.isImage ? Lib.imageInfo(modelData.preview) : null
                readonly property string thumb: modelData.isImage && !modelData.sample ? Clipboard.imagePath(modelData) : ""
                width: rows.width; height: rows.rowH
                // A damped lift under the pointer, a sink when pressed.
                scale: mouse.pressed ? 0.98 : mouse.containsMouse ? 1.015 : 1
                Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }

                Surface {
                    anchors.fill: parent
                    group: "widgets"
                    level: 1
                    radius: Tokens.radiusTile
                    outlined: true
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.radiusTile
                    color: Colors.alpha(Colors.text, mouse.containsMouse && !row.lit ? 0.06 : 0)
                    Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
                }
                ShellTint {
                    anchors.fill: parent
                    radius: Tokens.radiusTile
                    group: "widgets"
                    active: row.lit
                    hovered: mouse.containsMouse
                }

                // A picture: its thumbnail at the start.
                Item {
                    id: lead
                    visible: row.modelData.isImage
                    x: Math.round(Tokens.gap * 0.35)
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height - 2 * x
                    width: visible ? Math.round(height * 1.6) : 0
                    Rectangle {
                        anchors.fill: parent
                        visible: row.modelData.sample === true
                        radius: Tokens.radiusKnob
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Colors.ink(210) }
                            GradientStop { position: 1; color: Colors.ink(300) }
                        }
                    }
                    RoundImage {
                        id: pic
                        anchors.fill: parent
                        visible: row.thumb !== ""
                        radius: Tokens.radiusKnob
                        sourceWidth: Math.round(width * 2)
                        source: row.thumb ? "file://" + row.thumb : ""
                    }
                    // Not decoded yet (or would not): the picture's line glyph.
                    Icon {
                        anchors.centerIn: parent
                        visible: !row.modelData.sample && pic.status !== Image.Ready
                        name: "image"; size: Math.round(parent.height * 0.6); color: Colors.textDim
                    }
                }
                Label {
                    anchors { left: lead.visible ? lead.right : parent.left; leftMargin: Tokens.gap * 0.7; right: mark.left; rightMargin: Tokens.gap * 0.4; verticalCenter: parent.verticalCenter }
                    text: row.info ? "Picture · " + row.info.type + (row.info.w ? " " + row.info.w + "×" + row.info.h : "")
                        : row.modelData.isImage ? "Picture" : Lib.oneLine(row.modelData.preview)
                    role: row.modelData.isImage ? "dim" : "text"
                    size: Tokens.textSmall + 1
                    maximumLineCount: 1
                }
                Icon {
                    id: mark
                    anchors { right: parent.right; rightMargin: Tokens.gap * 0.6; verticalCenter: parent.verticalCenter }
                    name: row.lit ? "check" : "copy"
                    size: Tokens.textSize + 1
                    color: row.lit ? Colors.accent : Colors.textDim
                    opacity: row.lit || mouse.containsMouse ? 1 : 0
                    Behavior on opacity { enabled: Motion.enabled; EaseAnim {} }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    enabled: !root.preview
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.copy(row.modelData)
                }
            }
        }
    }
}
