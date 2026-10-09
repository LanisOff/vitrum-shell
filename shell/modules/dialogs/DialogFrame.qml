import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.components

/*
 * A system dialog: the whole screen dimmed, a card in the middle. Used for
 * password prompts and the power menu — things that must read as "the
 * system", never as an application window.
 */
PanelWindow {
    id: root
    required property var modelData
    property bool open: false
    default property alias content: inner.data
    signal dismissed()
    screen: modelData

    visible: true
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "vitrum-dialogs"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: root.open ? dim : dot }
    BlurKick { id: blurKick; window: root }
    BackgroundEffect.blurRegion: Materials.wantsRegion("dialogs") && !blurKick.on ? effect : blurKick.none
    Region { id: effect; item: root.open || card.opacity > 0.05 ? shape : dot; radius: Tokens.radiusPanel }
    Item { id: dot; width: 1; height: 1 }
    Item { id: shape; x: card.x; y: card.y; width: card.width; height: card.height }

    Rectangle {
        id: dim
        anchors.fill: parent
        color: Colors.alpha("#000000", root.open ? 0.45 : 0)
        Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.standard } }
        MouseArea { anchors.fill: parent; enabled: root.open; onClicked: root.dismissed() }
    }

    Surface {
        id: card
        group: "dialogs"
        width: inner.implicitWidth + 2 * Tokens.padding * 1.5
        height: inner.implicitHeight + 2 * Tokens.padding * 1.5
        anchors.centerIn: parent
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.94
        visible: opacity > 0
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
        Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
        MouseArea { anchors.fill: parent }
        Item {
            id: inner
            x: Tokens.padding * 1.5; y: Tokens.padding * 1.5
            implicitWidth: childrenRect.width; implicitHeight: childrenRect.height
        }
    }
    Item { focus: root.open; Keys.onEscapePressed: root.dismissed() }
}
