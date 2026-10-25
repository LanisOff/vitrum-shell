import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components

// One row in a section: label (and hint) on the left, the control on the right.
// Off (`enabled: false`, or the `needs` switch off), it takes no input and its
// label, hint and control dim, as a disabled GlassButton does.
Item {
    id: row
    property string label: ""
    property string hint: ""
    default property alias control: slot.data
    property bool divider: true
    /// An image before the label (an app's or a device's icon).
    property string leading: ""
    /// A line glyph (Icon) in the image's place when `leading` comes out empty
    /// (an app the icon theme has no icon for).
    property string leadingGlyph: ""
    /// A boolean settings key this row only means anything with (its master
    /// switch, e.g. "dock.magnify" for the magnification): off, the row is.
    property string needs: ""
    enabled: needs.length === 0 || Settings.get(needs, false) === true
    // The label, hint and control; the control takes no input while off (Item
    // passes `enabled` down). A GlassButton in a row that is off dims twice.
    readonly property real _dim: enabled ? 1 : 0.45
    width: parent ? parent.width : 400
    // Tall enough for the control too: chips that wrap to a second line spilled out of the card.
    implicitHeight: Math.max(Tokens.islandHeight * 1.6, texts.implicitHeight + Tokens.gap * 2, slot.implicitHeight + Tokens.gap * 2)
    HoverHandler { id: hover }
    Rectangle {
        anchors { fill: parent; margins: 3 }
        radius: Tokens.radiusInner - 3
        color: Colors.alpha(Colors.text, hover.hovered && row.enabled ? 0.04 : 0)
        Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
    }
    IconImage {
        id: lead
        visible: row.leading.length > 0 || row.leadingGlyph.length > 0
        implicitSize: Tokens.iconSize * 1.4
        opacity: row._dim
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
        anchors { left: parent.left; leftMargin: Tokens.padding; verticalCenter: parent.verticalCenter }
        source: row.leading
        Icon { anchors.centerIn: parent; visible: row.leading.length === 0; name: row.leadingGlyph || "help"; size: Math.round(parent.width * 0.8); color: Colors.textDim }
    }
    Column {
        id: texts
        opacity: row._dim
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
        anchors { left: lead.visible ? lead.right : parent.left; leftMargin: lead.visible ? Tokens.gap : Tokens.padding; verticalCenter: parent.verticalCenter; right: slot.left; rightMargin: Tokens.gap }
        Label { width: parent.width; text: row.label }
        Label { visible: row.hint.length > 0; width: parent.width; text: row.hint; role: "dim"; size: Tokens.textSmall; wrapMode: Text.WordWrap; elide: Text.ElideNone }
    }
    Row {
        id: slot
        opacity: row._dim
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
        anchors { right: parent.right; rightMargin: Tokens.padding; verticalCenter: parent.verticalCenter }
        spacing: Tokens.gap
    }
    Rectangle { visible: row.divider; anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: Tokens.padding } height: 1; color: Colors.alpha(Colors.text, 0.06) }
}
