import QtQuick
import qs.theme

/*
 * One of a set (a category, a size, a template, a colour): clear glass with
 * a rim (radius Tokens.radiusButton), a faint lift under the pointer, and the
 * lit glass (Tint) when it is the chosen one, drifting under the pointer. The
 * text stays Colors.text; a chosen one's icon takes the tint's colour. An optional swatch (a colour dot) and icon
 * go before the label; with neither a label nor a swatch it is a square.
 *
 *     GlassChoice { label: "Daily"; chosen: view.mode === "daily"; onClicked: view.mode = "daily" }
 */
Item {
    id: root
    property string label: ""
    property string icon: ""
    property bool chosen: false
    /// A colour dot before the label; transparent (the default) shows none.
    property color swatch: "transparent"
    property string group: "panels"
    property color tint: Colors.accent
    /// The rim while it is not chosen; false for a quiet grid (icons).
    property bool outlined: true
    property int labelSize: Tokens.textSmall + 1
    property int labelWeight: Font.Normal
    property real radius: Tokens.radiusButton
    readonly property bool hovered: enabled && mouse.containsMouse
    signal clicked()

    readonly property bool _square: label.length === 0 && swatch.a === 0
    implicitHeight: Tokens.islandHeight
    implicitWidth: _square ? implicitHeight : content.implicitWidth + Tokens.padding * 1.2
    opacity: enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: !root.chosen && root.hovered ? Colors.alpha(Colors.text, 0.08) : "transparent"
        Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
        border.width: root.outlined && !root.chosen ? Tokens.hairline : 0
        border.color: Colors.alpha(Colors.text, 0.25)
    }
    ShellTint {
        anchors.fill: parent
        radius: root.radius
        group: root.group
        tint: root.tint
        active: root.chosen
        hovered: root.hovered
    }
    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6
        Rectangle {
            visible: root.swatch.a > 0
            width: Tokens.textSmall + 4; height: width; radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: root.swatch
        }
        Icon {
            visible: root.icon.length > 0; name: root.icon || "help"
            // Chosen: the icon takes the tint's colour.
            color: root.chosen ? root.tint : Colors.text
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { enabled: Motion.enabled; ColorAnim {} }
        }
        Label { visible: root.label.length > 0; text: root.label; size: root.labelSize; font.weight: root.labelWeight; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
