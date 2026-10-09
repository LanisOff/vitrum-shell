import QtQuick
import Quickshell
import Quickshell.Wayland

// Test-only wallpaper for nested runs: the image in $VITRUM_TEST_WALL on the background layer.
ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "vitrum-wallpaper"
            color: "#202020"
            Image { anchors.fill: parent; source: "file://" + Quickshell.env("VITRUM_TEST_WALL"); fillMode: Image.PreserveAspectCrop }
        }
    }
}
