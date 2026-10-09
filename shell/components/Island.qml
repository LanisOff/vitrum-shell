import QtQuick
import qs.theme

// A bar island: a capsule that sizes to its content with a spring. The width
// is whole pixels, so the glass niri draws under it (whole-pixel regions) and
// the tint and outline drawn here keep the same edges while it moves.
Surface {
    id: root
    default property alias content: row.data
    readonly property alias row: row
    property int spacing: Tokens.gap

    group: "bar"
    height: Tokens.islandHeight
    radius: Tokens.islandRadius
    implicitWidth: row.implicitWidth + 2 * Tokens.padding
    /// The width it springs to (an island that hides itself sets 0).
    property real targetWidth: implicitWidth
    property real springWidth: targetWidth
    Behavior on springWidth { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }
    width: Math.round(springWidth)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: root.spacing
    }
}
