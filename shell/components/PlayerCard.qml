import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.services
import qs.theme
import "../lib/lock.js" as LockLib

/*
 * The player, as a card: the cover, blurred, fills it under the glass; the
 * sharp cover sits on it with the track and the controls; the progress is a
 * wave while it plays; synced lyrics scroll under it (Lyrics), the spectrum
 * (Cava) runs along the bottom. Tints come from the cover.
 *
 * Used by the bar's media panel (its own height) and the desktop's player
 * widget (fill: the height it is given; lyrics only when there is room).
 */
Item {
    id: root
    /// Take the height given (a widget) instead of the content's own (a panel).
    property bool fill: false
    property bool showLyrics: true
    /// No plate of its own: inside a desktop widget the widget's glass is the card.
    property bool bare: false
    readonly property real pad: bare ? 0 : fill ? Tokens.padding * 0.75 : Tokens.padding
    implicitHeight: body.implicitHeight + 2 * pad

    Component.onCompleted: { Cava.subscribe(); Lyrics.subscribe(); }
    Component.onDestruction: { Cava.unsubscribe(); Lyrics.unsubscribe(); }

    // The cover's most vivid colour, for the wave and the spectrum.
    ColorQuantizer {
        id: quant
        source: Media.artUrl
        depth: 3
        rescaleSize: 48
    }
    // Eased: the cover's colour arrives a moment after the cover, and the wave
    // and the spectrum would flip to it.
    property color tint: pickTint
    Behavior on tint { enabled: Motion.enabled; ColorAnim { duration: Motion.standard } }
    readonly property color pickTint: {
        let best = Colors.accent, score = -1;
        for (const c of quant.colors) {
            const s = c.hsvSaturation * (0.35 + c.hsvValue);
            if (c.hsvValue > 0.3 && s > score) { score = s; best = c; }
        }
        return best;
    }

    // ------------------------------------------------------- the card ---
    // The cover, blurred and tinted, under the content. Its edge is feathered
    // into the glass around it: a hard-edged box of blurred cover sat on the
    // refracted wallpaper like a sticker, its rounded corners most of all.
    readonly property real feather: Tokens.padding * 1.2
    readonly property bool hasArt: Media.artUrl.length > 0 && backArt.status === Image.Ready
    Item {
        id: back
        anchors.fill: parent
        visible: false
        Image { id: backArt; anchors.fill: parent; source: Media.artUrl; fillMode: Image.PreserveAspectCrop; sourceSize.width: 256; asynchronous: true }
    }
    // Soft mask: a rounded box inset by the feather, blurred out to the card's edge.
    Item {
        id: softMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle { id: maskCore; anchors.fill: parent; anchors.margins: root.feather * 0.6; radius: Tokens.radiusInner * 1.5; visible: false }
        MultiEffect { anchors.fill: maskCore; source: maskCore; blurEnabled: true; blur: 1.0; blurMax: Math.round(root.feather) }
    }
    Item {
        anchors.fill: parent
        visible: !root.bare && opacity > 0
        // The blurred cover comes in once it has loaded, not as a pop.
        opacity: root.hasArt ? 1 : 0
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.standard } }
        layer.enabled: visible
        layer.effect: MultiEffect { maskEnabled: true; maskSource: softMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
        MultiEffect {
            anchors.fill: parent
            source: back
            blurEnabled: true; blur: 1.0; blurMax: 48
            saturation: 0.15
        }
        Rectangle { anchors.fill: parent; color: Colors.alpha(Colors.surface, Colors.dark ? 0.45 : 0.55) }
    }
    // No cover: the plain plate.
    Rectangle {
        anchors.fill: parent
        visible: !root.bare && opacity > 0
        opacity: root.hasArt ? 0 : 1
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.standard } }
        radius: Tokens.radiusInner * 1.5
        color: Materials.fill("panels", 1)
    }

    Label { anchors.centerIn: parent; visible: !Media.available && !root.bare; text: "Nothing playing"; role: "dim" }

    Column {
        id: body
        visible: Media.available
        x: root.pad; y: root.pad
        width: root.width - 2 * root.pad
        spacing: root.fill ? Tokens.gap * 0.6 : Tokens.gap

        // The cover, and the track with its controls.
        Row {
            spacing: Tokens.gap * 1.5
            readonly property real cover: root.fill ? Math.min(Tokens.islandHeight * 4.4, Math.max(Tokens.islandHeight * 1.8, root.height * 0.4)) : Tokens.islandHeight * 3.4
            Rectangle {
                width: parent.cover; height: width; radius: Tokens.radiusInner
                color: Colors.surfaceHigh
                RoundImage {
                    id: art
                    anchors.fill: parent; source: Media.artUrl; sourceWidth: 256; radius: parent.radius
                    opacity: Media.artUrl.length > 0 && status === Image.Ready ? 1 : 0
                    Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.standard } }
                }
                Icon { anchors.centerIn: parent; name: "music"; size: Tokens.iconSize * 2; opacity: 1 - art.opacity; color: Colors.textDim }
            }
            Column {
                width: body.width - parent.cover - Tokens.gap * 1.5
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Label { width: parent.width; text: Media.title || Media.identity; size: root.fill ? Tokens.textSize : Tokens.textLarge; font.weight: Font.DemiBold; elide: Text.ElideRight }
                Label { width: parent.width; text: Media.artist; role: "dim"; elide: Text.ElideRight; visible: text.length > 0 }
                Label { width: parent.width; text: Media.album || Media.identity; role: "dim"; size: Tokens.textSmall; elide: Text.ElideRight; visible: !root.fill && text.length > 0 }
                Item { width: 1; height: Tokens.gap * (root.fill ? 0.4 : 1) }
                MediaControls { size: root.fill ? Tokens.islandHeight * 0.95 : Tokens.islandHeight * 1.05 }
            }
        }

        // The wave: up to where it is, a sine that moves while it plays.
        Item {
            id: wave
            width: body.width
            height: Tokens.islandHeight * 0.55
            readonly property real frac: Media.length > 0 ? Math.max(0, Math.min(1, pos / Media.length)) : 0
            property real pos: Media.position
            property real phase: 0
            NumberAnimation on phase { from: 0; to: Math.PI * 2; duration: 1600; loops: Animation.Infinite; running: Media.playing && Motion.enabled && wave.visible }
            Timer { interval: 500; repeat: true; running: Media.playing; onTriggered: wave.pos = Media.current ? Media.current.position : 0 }
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: root.tint; strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathPolyline {
                        path: {
                            const pts = [], w = wave.width * wave.frac, mid = wave.height / 2, amp = Media.playing ? wave.height * 0.22 : 0;
                            for (let x = 0; x <= w; x += 3) pts.push(Qt.point(x, mid + amp * Math.sin(x / 7 + wave.phase)));
                            if (!pts.length) pts.push(Qt.point(0, mid));
                            return pts;
                        }
                    }
                }
            }
            Rectangle {
                x: wave.width * wave.frac; anchors.verticalCenter: parent.verticalCenter
                width: wave.width - x; height: 3; radius: 1.5
                color: Colors.alpha(Colors.text, 0.25)
            }
            Rectangle {
                x: wave.width * wave.frac - width / 2; anchors.verticalCenter: parent.verticalCenter
                width: 4; height: wave.height * 0.8; radius: 2; color: Colors.text
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: m => { if (Media.length > 0) { Media.seek(m.x / width * Media.length); wave.pos = m.x / width * Media.length; } }
            }
        }
        Item {
            width: body.width; height: times.implicitHeight
            // In a widget too, when it is tall enough to spare the line.
            visible: !root.fill || root.height > Tokens.islandHeight * 4.5
            Label { id: times; text: LockLib.formatDuration(wave.pos); role: "dim"; size: Tokens.textSmall; numeric: true }
            Label { anchors.right: parent.right; text: LockLib.formatDuration(Media.length); role: "dim"; size: Tokens.textSmall; numeric: true }
        }

        // Synced lyrics: the line being sung in the middle (one line in a small widget).
        ListView {
            id: lyrics
            readonly property real lineH: Tokens.textLarge * 1.9
            readonly property int lines: root.fill ? (root.height > Tokens.islandHeight * 8 ? 3 : 1) : 3
            readonly property bool room: !root.fill || root.height > Tokens.islandHeight * 6
            visible: root.showLyrics && room && Lyrics.state === "synced" && Settings.get("media.lyrics", true)
            width: body.width
            height: visible ? lineH * lines : 0
            clip: true
            interactive: false
            model: Lyrics.lines
            currentIndex: Math.max(0, Lyrics.index)
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: lines === 3 ? lineH : 0
            preferredHighlightEnd: lines === 3 ? lineH * 2 : lineH
            highlightMoveDuration: Motion.enabled ? Motion.emphasized : 0
            delegate: Label {
                required property var modelData
                required property int index
                readonly property bool now: index === Lyrics.index
                width: lyrics.width; height: lyrics.lineH
                verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter
                text: modelData.text
                elide: Text.ElideRight
                size: now ? Tokens.textLarge : Tokens.textSize
                font.weight: now ? Font.DemiBold : Font.Normal
                color: now ? Colors.text : Colors.alpha(Colors.text, 0.45)
                Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.standard } }
                // An instrumental line: a note, as an icon.
                Icon { anchors.centerIn: parent; visible: !modelData.text; name: "music"; filled: true; color: parent.color; size: parent.font.pixelSize * 1.1 }
            }
        }

        // The spectrum: a fixed set of bars, each reading its value (a new
        // model every frame would rebuild them all thirty times a second).
        Row {
            id: spectrum
            visible: Settings.get("media.visualizer", true)
            // Paused or silent: the bars sink away rather than lie there as a dashed line.
            opacity: Cava.active && Cava.bars.length > 0 ? 1 : 0
            Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.standard } }
            width: body.width
            height: !visible ? 0 : root.fill ? Math.max(Tokens.islandHeight * 0.5, root.height - 2 * root.pad - y) : Tokens.islandHeight * 0.9
            spacing: 2
            Repeater {
                model: Cava.barCount
                Rectangle {
                    required property int index
                    readonly property real v: Cava.bars[index] || 0
                    width: (body.width - (Cava.barCount - 1) * 2) / Cava.barCount
                    height: Math.max(2, spectrum.height * v)
                    anchors.bottom: parent.bottom
                    radius: Math.min(width / 2, 3)
                    color: Colors.alpha(root.tint, 0.55 + 0.45 * v)
                }
            }
        }
    }
}
