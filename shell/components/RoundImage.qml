import QtQuick
import QtQuick.Effects

/*
 * An image cut to a rounded rectangle. `clip` only ever cuts square, so a
 * cover in a rounded frame kept its sharp corners; this masks it instead
 * (antialiased edge). Fades in once loaded.
 */
Item {
    id: root
    property alias source: img.source
    property alias status: img.status
    property alias fillMode: img.fillMode
    property alias cache: img.cache
    property int sourceWidth: 0
    property real radius: 0

    Image {
        id: img
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: root.sourceWidth
        visible: false
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: root.radius
        visible: false
        layer.enabled: true
        layer.smooth: true
    }
    MultiEffect {
        anchors.fill: parent
        source: img
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        visible: img.status === Image.Ready
    }
}
