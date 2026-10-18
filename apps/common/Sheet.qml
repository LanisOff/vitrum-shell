import QtQuick
import QtQuick.Controls as QQC
import qs.theme
import qs.components

// A form over the whole window, the window darkened behind it: a title, the
// content, and the buttons at the bottom (Cancel, then the main action).
// A pane declares it anywhere: it is a Qt popup, drawn in the window's
// overlay and centred on it (an item moved there by hand is not drawn in a
// Quickshell window).
//   open() / close(); accepted() when the main button (or Enter in a field) is
//   used; cancelled() on Cancel, Escape or a click outside.
QQC.Popup {
    id: sheet
    property string title: ""
    property string subtitle: ""
    property string acceptText: "Done"
    property bool acceptEnabled: true
    property bool danger: false
    property string error: ""
    property bool busy: false
    property real sheetWidth: 520
    default property alias content: body.data
    signal accepted()
    signal cancelled()

    function accept() { if (acceptEnabled && !busy) accepted(); }
    function cancel() { close(); cancelled(); }
    onAboutToShow: { error = ""; busy = false; }
    // The keyboard (for Escape) unless a field in it has it already.
    onOpened: {
        let a = flick.Window.activeFocusItem;
        while (a && a !== flick) a = a.parent;
        if (!a) flick.forceActiveFocus();
    }

    readonly property Item host: QQC.Overlay.overlay
    anchors.centerIn: host
    width: Math.min(sheetWidth, (host ? host.width : sheetWidth + Tokens.padding * 2) - Tokens.padding * 2)
    height: Math.min(col.implicitHeight + Tokens.padding * 2, (host ? host.height : 2000) - Tokens.padding * 2)
    padding: 0
    modal: true
    focus: true
    // Cancel, Escape and a click outside all say "cancelled"; a plain close() does not.
    closePolicy: QQC.Popup.NoAutoClose

    QQC.Overlay.modal: Rectangle {
        color: Colors.alpha("#000000", 0.45)
        MouseArea { anchors.fill: parent; onClicked: sheet.cancel() }
    }
    background: Surface {
        group: "dialogs"
        // Solid: an app window has no blur behind it for glass to show.
        color: Colors.bg
    }
    enter: Transition {
        enabled: Motion.enabled
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.fast; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: Motion.standard; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
    }
    exit: Transition {
        enabled: Motion.enabled
        NumberAnimation { property: "opacity"; to: 0; duration: Motion.fast; easing.type: Easing.InCubic }
    }

    contentItem: Flickable {
        id: flick
        contentWidth: width
        contentHeight: col.implicitHeight + Tokens.padding * 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Keys.onEscapePressed: sheet.cancel()
        Column {
            id: col
            x: Tokens.padding * 1.5; y: Tokens.padding
            // The popup's width, not the content item's (which follows its children: a loop to zero).
            width: sheet.width - Tokens.padding * 3
            spacing: Tokens.gap * 1.5
            Label { text: sheet.title; size: Tokens.textLarge; font.weight: Font.DemiBold; width: parent.width; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            Label { visible: sheet.subtitle.length > 0; text: sheet.subtitle; role: "dim"; width: parent.width; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            Column { id: body; width: parent.width; spacing: Tokens.gap }
            Label { visible: sheet.error.length > 0; text: sheet.error; role: "danger"; size: Tokens.textSmall; width: parent.width; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            Row {
                anchors.right: parent.right
                spacing: Tokens.gap
                Capsule { label: "Cancel"; onClicked: sheet.cancel() }
                Capsule {
                    label: sheet.busy ? "Working…" : sheet.acceptText
                    active: true
                    opacity: sheet.acceptEnabled && !sheet.busy ? 1 : 0.5
                    color: sheet.danger ? Colors.danger : Colors.accent
                    onClicked: sheet.accept()
                }
            }
        }
    }
}
