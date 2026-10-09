import QtQuick
import qs.theme

// A raised inner surface with padding, for content inside panels.
Surface {
    default property alias content: inner.data
    group: "panels"
    level: 1
    outlined: false
    radius: Tokens.radiusInner
    implicitWidth: inner.implicitWidth + 2 * Tokens.padding
    implicitHeight: inner.implicitHeight + 2 * Tokens.padding
    Item { id: inner; anchors.fill: parent; anchors.margins: Tokens.padding; implicitWidth: childrenRect.width; implicitHeight: childrenRect.height }
}
