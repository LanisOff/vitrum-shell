import QtQuick
import ".."
import qs.services
import qs.theme
import qs.components

// Dots while something listens or watches: orange the microphone, green the
// camera, purple the screen. Click: who, and a way to stop it.
BarModule {
    id: root
    shown: Privacy.any
    panel: "privacy"
    implicitWidth: dots.implicitWidth
    readonly property real d: Math.round(Tokens.islandHeight * 0.24)

    Row {
        id: dots
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(root.d * 0.6)
        Repeater {
            model: [{ on: Privacy.mic, c: "#ff9f0a" }, { on: Privacy.camera, c: "#30d158" }, { on: Privacy.screen, c: "#bf5af2" }]
            Rectangle {
                required property var modelData
                visible: modelData.on
                width: root.d; height: root.d; radius: root.d / 2
                color: modelData.c
                anchors.verticalCenter: parent.verticalCenter
                SequentialAnimation on opacity {
                    running: parent.visible && Motion.enabled
                    loops: 1
                    NumberAnimation { from: 0; to: 1; duration: Motion.standard }
                }
            }
        }
    }
}
