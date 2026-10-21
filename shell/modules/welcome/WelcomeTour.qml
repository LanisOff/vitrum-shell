import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.components
import "../../lib/welcome.js" as Lib

/*
 * The welcome tour: one step at a time over a dimmed desktop — the title, what
 * it does, its keys as caps, and Back / Next / Skip. Esc skips.
 *
 * The installer leaves a marker, ~/.local/share/vitrum/welcome, on a fresh
 * install. The tour opens when the marker is there at shell start, and the
 * marker goes whenever the tour closes: done, skipped, or closed by another
 * overlay opening (the tour itself invites Mod+Space). Otherwise it would come
 * back at every login. `vitrum-ipc welcome open` shows it again by hand.
 */
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property bool open: UiState.welcome && screen.name === (Niri.focusedOutput || Quickshell.screens[0].name)

    readonly property string markerPath: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/vitrum/welcome"
    readonly property var steps: Lib.steps()
    property int index: 0
    readonly property var step: steps[Math.min(index, steps.length - 1)]

    MapGate { id: gate; want: root.open || !UiState.parkOverlays }
    visible: gate.mapped
    // Mapped again by opening: the window is a new one, the focus goes back in.
    onBackingWindowVisibleChanged: if (backingWindowVisible && open) keys.forceActiveFocus()
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "vitrum-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: root.open ? catcher : dot }
    BlurKick { id: blurKick; window: root }
    BackgroundEffect.blurRegion: Materials.wantsRegion("overlay", blurKick.screen) && !blurKick.on ? effect : blurKick.none
    Region { id: effect; item: root.open || card.opacity > 0 ? shape : dot; radius: Tokens.radiusPanel }
    Item { id: dot; width: 1; height: 1 }
    Item { id: shape; x: card.x + (card.width - card.width * card.scale) / 2; y: card.y + (card.height - card.height * card.scale) / 2; width: card.width * card.scale; height: card.height * card.scale }

    // The marker, at shell start: its being there opens the tour.
    FileView {
        path: root.markerPath
        printErrors: false
        onLoaded: UiState.welcome = true
    }
    Process { id: forget; command: ["rm", "-f", root.markerPath] }
    // Closed by any means (closeAll, closeOverlays, IPC, finish): seen once.
    Connections {
        target: UiState
        function onWelcomeChanged() { if (!UiState.welcome) forget.running = true; }
    }

    onOpenChanged: if (open) { index = 0; keys.forceActiveFocus(); }

    // Done or skipped: closed, which takes the marker with it.
    function finish() { UiState.welcome = false; }
    function advance() {
        const n = Lib.next(index, steps.length);
        if (n >= steps.length) finish(); else index = n;
    }
    function back() { index = Lib.prev(index); }

    Rectangle {
        anchors.fill: parent
        color: Colors.alpha("#000000", root.open ? 0.35 : 0)
        Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.standard } }
    }
    MouseArea { id: catcher; anchors.fill: parent }

    Surface {
        id: card
        group: "overlay"
        width: Math.min(root.width * 0.9, Tokens.islandHeight * 14)
        height: content.implicitHeight + 2 * Tokens.padding * 1.5
        anchors.centerIn: parent
        radius: Tokens.radiusPanel
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.96
        visible: opacity > 0
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
        Behavior on scale { enabled: Motion.enabled; NumberAnimation { duration: Motion.standard; easing.type: Easing.OutQuint } }
        MouseArea { anchors.fill: parent }   // clicks inside do nothing

        FocusScope {
            id: keys
            anchors.fill: parent
            focus: root.open
            Keys.onEscapePressed: root.finish()
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Right || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { root.advance(); event.accepted = true; }
                else if (event.key === Qt.Key_Left) { root.back(); event.accepted = true; }
            }

            Column {
                id: content
                x: Tokens.padding * 1.5; y: Tokens.padding * 1.5
                width: card.width - 2 * x
                spacing: Tokens.gap * 1.5

                Label { text: "WELCOME TO VITRUM"; role: "accent"; size: Tokens.textSmall; font.weight: Font.DemiBold; font.letterSpacing: 1.2 }
                Label { width: parent.width; text: root.step.title; size: Tokens.textLarge; font.weight: Font.DemiBold; wrapMode: Text.WordWrap }
                Label { width: parent.width; text: root.step.body; role: "dim"; wrapMode: Text.WordWrap }

                // The step's keys, as caps like the keybind sheet's.
                Row {
                    visible: root.step.keys.length > 0
                    spacing: 3
                    Repeater {
                        model: root.step.keys
                        delegate: Rectangle {
                            required property string modelData
                            height: Tokens.textSize * 1.7
                            width: Math.max(height, capLabel.implicitWidth + Tokens.gap * 1.2)
                            radius: Tokens.radiusInner * 0.7
                            color: Colors.alpha(Colors.text, 0.08)
                            border.width: 1
                            border.color: Colors.alpha(Colors.text, 0.14)
                            Label { id: capLabel; anchors.centerIn: parent; text: parent.modelData; size: Tokens.textSmall; font.weight: Font.DemiBold }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: Tokens.islandHeight * 1.1
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.index + 1) + " of " + root.steps.length
                        role: "dim"; size: Tokens.textSmall
                    }
                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: Tokens.gap
                        Repeater {
                            model: [
                                { label: "Skip", primary: false, show: true, act: 0 },
                                { label: "Back", primary: false, show: root.index > 0, act: 1 },
                                { label: root.index >= root.steps.length - 1 ? "Done" : "Next", primary: true, show: true, act: 2 }
                            ]
                            delegate: Surface {
                                id: btn
                                required property var modelData
                                visible: modelData.show
                                group: "overlay"
                                level: 1
                                outlined: false
                                height: Tokens.islandHeight * 1.1
                                width: btnLabel.implicitWidth + Tokens.padding * 2
                                radius: height / 2
                                color: modelData.primary ? Colors.accent : mouse.containsMouse ? Colors.alpha(Colors.text, 0.12) : Materials.fill(group, 1, root.screen.name)
                                Label { id: btnLabel; anchors.centerIn: parent; text: btn.modelData.label; role: btn.modelData.primary ? "onAccent" : "text"; font.weight: Font.DemiBold }
                                MouseArea {
                                    id: mouse
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (btn.modelData.act === 0) root.finish(); else if (btn.modelData.act === 1) root.back(); else root.advance(); }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
