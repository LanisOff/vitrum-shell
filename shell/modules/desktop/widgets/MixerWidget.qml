import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components
import "../../../lib/mixer.js" as Lib

/*
 * Per-app volume (Audio.streams, PipeWire's playback streams): a row per app
 * that plays sound, its icon and name, a slider, and a mute key that glows
 * while the app is muted. An app's streams (a browser's tabs) are one row.
 *   M   the header (the output device at its end); two or three rows
 *   L   as M, with room for more rows
 * Rows that do not fit make way for an "and N more" line.
 * options: output (a row for the output device's own volume first).
 * Nothing polls: the nodes push their changes. In a gallery card, sample
 * apps stand in, and nothing is touched.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    // The output device's row only when there is one (preview: a sample one).
    readonly property bool outputRow: options.output === true && (preview || Audio.available)
    // [name, desktop icon, volume, muted]
    readonly property var sample: [["Firefox", "firefox", 0.72, false], ["Spotify", "spotify", 0.45, false],
                                   ["Discord", "discord", 0.9, true], ["mpv", "mpv", 1, false]]
        .map(a => ({ app: a[0], icon: a[1], volume: a[2], muted: a[3] }))
    readonly property var streams: preview ? [] : Audio.streams
    // Only the names and icons decide the rows; volume and mute are read live
    // in each row, so a drag does not rebuild the list under the pointer.
    readonly property var groups: preview ? Lib.group(sample)
        : Lib.group(streams.map(n => ({ app: Audio.streamName(n), icon: Audio.streamIcon(n) })))
    readonly property var rows: (outputRow ? [{ kind: "output" }] : []).concat(groups)

    readonly property real rowH: Tokens.islandHeight
    readonly property real spacing: Math.round(Tokens.gap * 0.45)
    readonly property var fit: Lib.fit(rows.length, list.height, rowH, spacing)

    WidgetHeader {
        id: head
        icon: "mixer"; title: "Mixer"
        trailing: root.preview ? "Speakers" : Audio.sinkName
    }
    WidgetEmpty {
        visible: root.rows.length === 0
        anchors.verticalCenterOffset: head.height / 2
        icon: "volume-mute"
        text: "Nothing is playing"
    }

    Column {
        id: list
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: Tokens.gap * 0.6; bottom: parent.bottom }
        spacing: root.spacing
        Repeater {
            model: root.rows.slice(0, root.fit.rows)
            delegate: Item {
                id: row
                required property var modelData
                readonly property bool isOutput: modelData.kind === "output"
                readonly property var nodes: root.preview || isOutput ? [] : modelData.members.map(i => root.streams[i]).filter(n => n)
                readonly property real volume: root.preview ? modelData.volume
                    : isOutput ? Audio.volume
                    : nodes.reduce((m, n) => Math.max(m, n.audio ? n.audio.volume : 0), 0)
                readonly property bool muted: root.preview ? modelData.muted
                    : isOutput ? Audio.muted
                    : nodes.length > 0 && nodes.every(n => n.audio && n.audio.muted)
                function setVolume(v) {
                    if (isOutput) Audio.setVolume(v);
                    else for (const n of nodes) Audio.setStreamVolume(n, v);
                }
                function toggleMute() {
                    if (isOutput) Audio.toggleMute();
                    else { const m = !muted; for (const n of nodes) Audio.setStreamMuted(n, m); }
                }
                width: list.width; height: root.rowH

                // The app's own icon; a line glyph for the output, or when the theme has none.
                Item {
                    id: lead
                    width: Math.round(root.rowH * 0.8); height: width
                    anchors.verticalCenter: parent.verticalCenter
                    IconImage {
                        id: appIcon
                        anchors.fill: parent
                        visible: !row.isOutput && source != ""
                        source: row.isOutput ? "" : Apps.iconSource(row.modelData.icon)
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: !appIcon.visible
                        name: row.isOutput ? "speaker" : "music"
                        size: Math.round(parent.width * 0.8)
                        color: Colors.accent2
                    }
                }
                Label {
                    id: name
                    anchors { left: lead.right; leftMargin: Tokens.gap * 0.6; verticalCenter: parent.verticalCenter }
                    width: Math.round(list.width * 0.26)
                    text: row.isOutput ? "Output" : row.modelData.app
                    size: Tokens.textSmall + 1; font.weight: Font.Medium
                }
                Slider {
                    anchors { left: name.right; leftMargin: Tokens.gap * 0.5; right: mute.left; rightMargin: Tokens.gap * 0.5; verticalCenter: parent.verticalCenter }
                    height: root.rowH
                    group: "widgets"
                    icon: ""
                    value: row.volume
                    enabled: !root.preview
                    opacity: row.muted ? 0.5 : 1
                    Behavior on opacity { enabled: Motion.enabled; EaseAnim {} }
                    onMoved: v => row.setVolume(v)
                }
                GlassButton {
                    id: mute
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: root.rowH; height: root.rowH
                    group: "widgets"
                    icon: row.muted ? "volume-mute" : "volume-high"
                    primary: row.muted
                    enabled: !root.preview
                    // A gallery card shows the state as it is, not dimmed.
                    opacity: 1
                    onClicked: row.toggleMute()
                }
            }
        }
        Label {
            visible: root.fit.more > 0
            width: list.width
            height: root.rowH
            text: "and " + root.fit.more + " more"
            role: "dim"; size: Tokens.textSmall
        }
    }
}
