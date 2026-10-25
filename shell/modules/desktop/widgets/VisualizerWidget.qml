import QtQuick
import qs.services
import qs.theme
import qs.components

/*
 * What plays, as a spectrum (Cava): decor, so no header at any size.
 *   S–XL  bars filling the area, softly rounded tops; mirrored, they grow from
 *         the centre line both ways. Fewer, wider bars when the widget is narrow.
 *         Dichroic: the colour turns from the tint to its pair (accent → accent2)
 *         across the bars.
 *   L/XL  with nothing playing, a small dim note in the middle.
 * options: mirror, color. Silent, the bars sink to a 2 px line.
 * In a gallery card a still curve stands in, and cava is never started.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    // The host sets preview after Component.onCompleted, so the subscription
    // waits a tick and follows it: a gallery card must not start cava.
    property bool _subscribed: false
    function _sync() {
        const want = !preview;
        if (want && !_subscribed) { Cava.subscribe(); _subscribed = true; }
        else if (!want && _subscribed) { Cava.unsubscribe(); _subscribed = false; }
    }
    onPreviewChanged: _sync()
    Component.onCompleted: Qt.callLater(_sync)
    Component.onDestruction: if (_subscribed) Cava.unsubscribe()

    readonly property bool mirror: options.mirror === true
    readonly property color tint: {
        const c = options.color;
        return !c || c === "accent" ? Colors.accent : Colors.ink(Number(c));
    }
    readonly property color tint2: Colors.pair(tint)
    // The colour of bar i: the tint at the left, its pair at the right.
    function hue(i) {
        const t = i / Math.max(1, count - 1);
        return Qt.rgba(tint.r + (tint2.r - tint.r) * t, tint.g + (tint2.g - tint.g) * t, tint.b + (tint2.b - tint.b) * t, 1);
    }
    readonly property bool live: !preview && Cava.active && Cava.bars.length > 0
    readonly property real spacing: Math.max(2, Math.round(width / 110))
    // About one bar per 9 px, at most what cava gives.
    readonly property int count: Math.max(8, Math.min(Cava.barCount, Math.floor((width + spacing) / (7 + spacing))))
    readonly property real barW: (width - (count - 1) * spacing) / count

    // A bar's level: the loudest of the cava bars it stands for.
    function level(i) {
        if (preview) {
            const t = i / Math.max(1, count - 1);
            return 0.18 + 0.62 * Math.pow(Math.sin(Math.PI * (0.12 + t * 0.8)), 1.6) + 0.08 * Math.sin(t * 19);
        }
        if (!live) return 0;
        const per = Cava.bars.length / count;
        let v = 0;
        for (let k = Math.floor(i * per); k < Math.max(Math.floor(i * per) + 1, Math.floor((i + 1) * per)); k++)
            v = Math.max(v, Cava.bars[k] || 0);
        return v;
    }

    Repeater {
        model: root.count
        delegate: Item {
            id: slot
            required property int index
            readonly property real v: Math.max(0, Math.min(1, root.level(index)))
            x: index * (root.barW + root.spacing)
            width: root.barW
            height: root.height
            // Square feet: the bar runs a radius past the bottom and is cut there.
            clip: !root.mirror
            readonly property color hue: root.hue(index)
            Rectangle {
                id: bar
                readonly property real r: Math.min(width / 2, Tokens.radiusMeter)
                // The visible height; animated, so not readonly.
                property real h: Math.max(2, slot.height * slot.v)
                width: parent.width
                height: root.mirror ? h : h + r
                y: root.mirror ? (slot.height - h) / 2 : slot.height - h
                radius: Math.min(r, height / 2)
                color: Colors.alpha(slot.hue, 0.45 + 0.55 * slot.v)
                // A short glide between cava's frames, and a slow sink into silence.
                Behavior on h { enabled: Motion.enabled; NumberAnimation { duration: root.live ? 70 : Motion.emphasized; easing.type: Easing.OutCubic } }
            }
        }
    }

    WidgetEmpty {
        visible: !root.preview && !root.live && (root.sizeClass === "L" || root.sizeClass === "XL")
        icon: "music"
        text: "Nothing playing"
        opacity: 0.7
    }
}
