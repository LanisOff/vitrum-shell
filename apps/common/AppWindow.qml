import QtQuick
import Quickshell
import qs.theme
import qs.components

/*
 * An application window in the vitrum style: the window material, a title
 * row with the app's name and a close button, Escape closes. niri draws the
 * shadow and the window material (window rule for the app id).
 */
FloatingWindow {
    id: win
    property string appTitle: ""
    default property alias content: body.data
    property alias titleRow: extra.data
    signal closing()

    title: appTitle
    // Opaque: these are forms to read, and the desktop showing through got in the way.
    color: Colors.bg
    implicitWidth: 960
    implicitHeight: 640
    minimumSize: Qt.size(560, 400)

    function close() { closing(); Qt.quit(); }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: win.close()

        Item {
            id: head
            width: parent.width
            height: Tokens.islandHeight + Tokens.gap * 2
            Label {
                anchors { left: parent.left; leftMargin: Tokens.padding * 1.5; verticalCenter: parent.verticalCenter }
                text: win.appTitle
                font.weight: Font.DemiBold
                size: Tokens.textLarge
            }
            Row {
                id: extra
                anchors { right: closeBtn.left; rightMargin: Tokens.gap; verticalCenter: parent.verticalCenter }
                spacing: Tokens.gap
            }
            // Clear glass; under the pointer the danger tint comes in.
            GlassButton {
                id: closeBtn
                anchors { right: parent.right; rightMargin: Tokens.padding; verticalCenter: parent.verticalCenter }
                width: Tokens.islandHeight * 0.9; height: width
                icon: "close"
                danger: true
                primary: hovered
                onClicked: win.close()
            }
        }
        Item {
            id: body
            anchors { top: head.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        }
    }
}
