import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import qs.common
import "../lib/wallpaper.js" as WLib

Page {
    id: page
    title: "Wallpaper"
    subtitle: "Pick from your wallpaper folder; images and videos. The colours follow the wallpaper unless a preset is chosen (Appearance)."
    readonly property string home: Quickshell.env("HOME")
    readonly property string dir: WLib.expand(Settings.get("wallpaper.dir", "~/Pictures/Wallpapers"), home)
    readonly property string current: WLib.expand(Settings.get("wallpaper.path", ""), home)
    property string target: ""          // "" = every screen, else one output name
    property var files: []

    Process {
        id: lister
        running: true
        command: ["sh", "-c", 'find "$1" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" -o -iname "*.gif" \\) | sort', "_", page.dir]
        stdout: StdioCollector { onStreamFinished: page.files = text.split("\n").filter(s => s) }
    }
    onDirChanged: lister.running = true

    function pick(path) {
        if (page.target) {
            const per = Object.assign({}, Settings.get("wallpaper.perOutput", {}));
            per[page.target] = path;
            Settings.set("wallpaper.perOutput", per);
        } else {
            Settings.set("wallpaper.perOutput", {});
            Settings.set("wallpaper.path", path);
        }
    }

    Section {
        SettingText { key: "wallpaper.dir"; label: "Folder"; fieldWidth: Tokens.islandHeight * 12 }
        SettingRow {
            label: "Apply to"; divider: false
            Repeater {
                model: [""].concat(Quickshell.screens.map(s => s.name))
                delegate: Rectangle {
                    required property string modelData
                    readonly property bool on: page.target === modelData
                    height: Tokens.islandHeight * 1.05; radius: height / 2; width: tl.implicitWidth + Tokens.padding * 1.4
                    color: on ? Colors.accent : Colors.alpha(Colors.text, 0.06)
                    Label { id: tl; anchors.centerIn: parent; text: modelData || "Every screen"; role: parent.on ? "onAccent" : "text"; size: Tokens.textSmall + 1 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.target = modelData }
                }
            }
        }
    }
    Section {
        title: page.files.length ? page.files.length + " in the folder" : "Nothing in the folder"
        Grid {
            id: grid
            width: parent.width
            padding: Tokens.padding
            columns: Math.max(2, Math.floor((width - 2 * Tokens.padding) / 180))
            spacing: Tokens.gap
            readonly property real cell: (width - 2 * Tokens.padding - (columns - 1) * spacing) / columns
            Repeater {
                model: page.files
                delegate: Rectangle {
                    required property string modelData
                    readonly property bool video: WLib.isVideo(modelData)
                    readonly property bool on: modelData === page.current || (page.target && WLib.pathFor(Settings.get("wallpaper", {}), page.target, page.home) === modelData)
                    width: grid.cell; height: width * 0.62; radius: Tokens.radiusInner
                    color: Colors.alpha(Colors.text, 0.06)
                    border.width: on ? 3 : 0; border.color: Colors.accent
                    // Cut to the frame's rounding (clip only cuts square), inside the selection ring.
                    RoundImage { anchors.fill: parent; anchors.margins: parent.border.width; visible: !parent.video; source: parent.video ? "" : "file://" + modelData
                                 sourceWidth: 360; radius: Math.max(0, parent.radius - parent.border.width) }
                    Column { anchors.centerIn: parent; visible: parent.video; spacing: 4
                             Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "video"; size: Tokens.iconSize * 2 }
                             Label { width: grid.cell - Tokens.padding; horizontalAlignment: Text.AlignHCenter; text: modelData.split("/").pop(); role: "dim"; size: Tokens.textSmall } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.pick(modelData) }
                }
            }
        }
    }
    Section {
        title: "Behaviour"
        SettingChoice { key: "wallpaper.transition"; label: "Change with"; names: ({ grow: "Grow", fade: "Fade", none: "Nothing" }) }
        SettingToggle { key: "wallpaper.parallax"; label: "Parallax"; hint: "The picture moves a little as you change workspace. Costs GPU." }
        SettingToggle { key: "wallpaper.live.enabled"; label: "Play video wallpapers" }
        SettingToggle { key: "wallpaper.live.pauseWhenCovered"; label: "Pause videos when windows cover them"; divider: false }
    }
    // Keys set from this pane without a row of their own:
    readonly property var _keys: ["wallpaper.path", "wallpaper.perOutput"]
    Section {
        title: "Day and night"
        SettingToggle { key: "wallpaper.dayNight"; label: "Day and night pictures"; hint: "With automatic light and dark, a wallpaper named …-day.jpg changes to …-night.jpg (and back) when the scheme does."; divider: false }
    }
}
