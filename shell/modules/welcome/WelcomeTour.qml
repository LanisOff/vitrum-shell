import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components
import "../../lib/welcome.js" as Lib
import "../../lib/lock.js" as LockLib

/*
 * The welcome tour: a large glass window over a dimmed desktop, one step at a
 * time. On the left a live miniature of the part of the shell the step is
 * about (Art*.qml: the real components on the user's own wallpaper, with
 * placeholders for the data), on the right the step's title, what it does and
 * its keys as caps; under both the step marks (the current one lit and wider,
 * a click jumps there), Skip, Back and Next. ←/→, Enter and Space move, Esc
 * skips.
 *
 * Motion (all damped, none at rest): the window rises in and its parts follow
 * one after another; between steps the miniature slides in the direction of
 * travel, faster than the text beside it, and the wallpaper under it moves
 * least of all; each miniature plays its little demo once when it appears.
 *
 * The installer leaves a marker, ~/.local/share/vitrum/welcome, on a fresh
 * install. The tour opens when the marker is there at shell start, and the
 * marker goes whenever the tour closes: done, skipped, or closed by another
 * overlay opening (the tour itself invites Mod+Space). Otherwise it would come
 * back at every login. `vitrum-ipc welcome open` shows it again by hand;
 * `welcome next|back|go <n>|step` move it from outside (and tests).
 */
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property bool open: UiState.welcome && screen.name === (Niri.focusedOutput || Quickshell.screens[0].name)

    readonly property string markerPath: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/vitrum/welcome"
    readonly property var steps: Lib.steps()
    readonly property int count: steps.length
    property int index: 0
    readonly property var step: steps[Math.min(index, count - 1)]

    // The change of step: the one going (-1: none), which way (+1 forward),
    // and t, 0 when it starts … 1 when it has settled.
    property int leaving: -1
    property int dir: 1
    property real t: 1
    // The window's entrance, 0 … 1: its parts come in one after another.
    property real openT: 1

    MapGate { id: gate; want: root.open || !UiState.parkOverlays }
    visible: gate.mapped
    // Mapped again by opening: the window is a new one, the focus goes back in.
    onBackingWindowVisibleChanged: if (backingWindowVisible && open) keys.forceActiveFocus()
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "vitrum-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: root.open ? catcher : dot }
    BlurKick { id: blurKick; window: root }
    BackgroundEffect.blurRegion: Materials.wantsRegion("overlay", blurKick.screen) && !blurKick.on ? effect : blurKick.none
    Region { id: effect; item: root.open || card.opacity > 0 ? shape : dot; radius: Tokens.radiusPanel }
    // Off the screen's top-left pixel: the top-left hot corner sits there, under this layer.
    Item { id: dot; x: 2; y: 2; width: 1; height: 1 }
    Item { id: shape; x: card.x + (card.width - card.width * card.scale) / 2; y: card.y + (card.height - card.height * card.scale) / 2; width: card.width * card.scale; height: card.height * card.scale }

    // The marker, at shell start: its being there opens the tour.
    FileView {
        path: root.markerPath
        printErrors: false
        onLoaded: UiState.welcome = true
    }
    Process { id: forget; command: ["rm", "-f", root.markerPath] }
    // Closed by any means (closeAll, closeOverlays, IPC, finish): seen once.
    Connections {
        target: UiState
        function onWelcomeChanged() { if (!UiState.welcome) forget.running = true; }
        function onWelcomeMove(delta) { if (!root.open) return; if (delta > 0) root.advance(); else root.back(); }
        function onWelcomeGo(step) { if (root.open) root.go(step); }
    }

    onOpenChanged: {
        if (!open) return;
        stepAnim.stop();
        index = 0; leaving = -1; t = 1;
        UiState.welcomeStep = 0;
        if (Motion.enabled) openAnim.restart(); else openT = 1;
        keys.forceActiveFocus();
    }
    onIndexChanged: if (open) UiState.welcomeStep = index

    // Done or skipped: closed, which takes the marker with it.
    function finish() { UiState.welcome = false; }
    function go(n) {
        n = Lib.clampStep(n, count);
        if (n === index) return;
        dir = n > index ? 1 : -1;
        leaving = index;
        index = n;
        if (Motion.enabled) stepAnim.restart(); else { t = 1; leaving = -1; }
    }
    function advance() {
        const n = Lib.next(index, count);
        if (n >= count) finish(); else go(n);
    }
    function back() { go(Lib.prev(index)); }

    NumberAnimation { id: stepAnim; target: root; property: "t"; from: 0; to: 1; duration: Math.round(Motion.emphasized * 1.8); onFinished: root.leaving = -1 }
    NumberAnimation { id: openAnim; target: root; property: "openT"; from: 0; to: 1; duration: Math.round(Motion.emphasized * 2.4) }

    // ------------------------------------------------------------ surface ---
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, root.open ? 0.4 : 0)
        Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.emphasized } }
    }
    MouseArea { id: catcher; anchors.fill: parent }

    Surface {
        id: card
        group: "overlay"
        readonly property real u: Tokens.islandHeight
        // About 62 % × 64 % of the screen, held between sensible sizes (and
        // inside the screen when it is smaller than those).
        width: Math.round(Math.min(root.width - Tokens.gap * 4, Math.max(u * 25, Math.min(u * 39, root.width * 0.62))))
        height: Math.round(Math.min(root.height - Tokens.gap * 4, Math.max(u * 17.5, Math.min(u * 25, root.height * 0.64))))
        anchors.centerIn: parent
        // It rises into place, and settles a little as it goes.
        anchors.verticalCenterOffset: root.open ? 0 : Tokens.gap * 3
        radius: Tokens.radiusPanel
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.96
        visible: opacity > 0
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: root.open ? Motion.emphasized : Motion.standard } }
        Behavior on scale { enabled: Motion.enabled; NumberAnimation { duration: Math.round(Motion.emphasized * 1.3); easing.type: Easing.OutQuint } }
        Behavior on anchors.verticalCenterOffset { enabled: Motion.enabled; NumberAnimation { duration: Math.round(Motion.emphasized * 1.3); easing.type: Easing.OutQuint } }
        MouseArea { anchors.fill: parent }   // clicks inside do nothing

        // The layout: the art on the left and the text on the right, or (on
        // a small screen) the art over the text; the footer under both.
        readonly property real pad: Math.round(Tokens.padding * 1.8)
        readonly property bool wide: width >= u * 22
        readonly property real footerH: Math.round(u * 1.2)
        readonly property real colGap: Math.round(Tokens.padding * 2.6)
        readonly property real bodyH: height - 2 * pad - footerH - Math.round(pad * 0.8)
        readonly property real artW: wide ? Math.round((width - 2 * pad - colGap) * 0.56) : width - 2 * pad
        readonly property real artH: wide ? bodyH : Math.round(bodyH * 0.5)

        FocusScope {
            id: keys
            anchors.fill: parent
            focus: root.open
            Keys.onEscapePressed: root.finish()
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Right || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { root.advance(); event.accepted = true; }
                else if (event.key === Qt.Key_Left) { root.back(); event.accepted = true; }
                else if (event.key === Qt.Key_Home) { root.go(0); event.accepted = true; }
                else if (event.key === Qt.Key_End) { root.go(root.count - 1); event.accepted = true; }
            }

            // ------------------------------------------------------- art ---
            Item {
                id: artBox
                x: card.pad; y: card.pad
                width: card.artW; height: card.artH
                readonly property real o: Lib.phase(root.openT, 0, 0.45)
                opacity: o
                transform: Translate { y: (1 - artBox.o) * Tokens.gap * 2 }

                ClippingRectangle {
                    id: art
                    anchors.fill: parent
                    radius: Tokens.radiusTile
                    color: Colors.surface
                    // The miniatures' scale: their own size from the islands,
                    // fitted to the frame.
                    readonly property real s: Math.max(0.72, Math.min(1.15, width / (card.u * 15)))
                    readonly property real slide: width * 0.24

                    // No wallpaper (yet): a wash in the wallpaper's own tones.
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0; color: Colors.tone(-30, -0.06) }
                            GradientStop { position: 1; color: Colors.tone(40, -0.2) }
                        }
                    }
                    // The wallpaper, softened, as the desktop under the
                    // miniatures. It moves least of all between steps.
                    Item {
                        id: wallBox
                        readonly property real extra: Math.round(art.width * 0.1)
                        width: art.width + extra; height: art.height
                        x: -extra * root.index / Math.max(1, root.count - 1)
                        Behavior on x { enabled: Motion.enabled; NumberAnimation { duration: Math.round(Motion.emphasized * 2.4); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.glide } }
                        readonly property string path: LockLib.lockBackground(Wallpaper.pathFor(root.screen.name),
                            (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/vitrum/poster.png")
                        Image {
                            id: wall
                            anchors.fill: parent
                            source: card.visible && wallBox.path ? "file://" + wallBox.path : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize: Qt.size(Math.round(width), Math.round(height))
                            visible: false
                        }
                        MultiEffect {
                            anchors.fill: parent
                            source: wall
                            visible: wall.status === Image.Ready
                            blurEnabled: true; blurMax: 48; blur: 0.5
                            brightness: Colors.dark ? -0.1 : 0
                            saturation: 0.1
                        }
                    }
                    // A little shade at the bottom and top, so the glass on it reads.
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0; color: Colors.alpha(Colors.bg, 0.16) }
                            GradientStop { position: 0.5; color: Colors.alpha(Colors.bg, 0.02) }
                            GradientStop { position: 1; color: Colors.alpha(Colors.bg, 0.22) }
                        }
                    }

                    // The miniatures, at their own scale: the current one and
                    // the one going, each made when it shows (its demo plays then).
                    Item {
                        id: stage
                        width: art.width / art.s; height: art.height / art.s
                        scale: art.s
                        transformOrigin: Item.TopLeft
                        Repeater {
                            model: root.count
                            delegate: Loader {
                                id: slot
                                required property int index
                                readonly property bool current: index === root.index
                                readonly property bool going: index === root.leaving
                                readonly property real pIn: Lib.phase(root.t, 0, 0.85)
                                readonly property real pOut: Lib.phase(root.t, 0, 0.7)
                                width: stage.width; height: stage.height
                                active: card.visible && (current || going)
                                visible: active
                                x: (current ? root.dir * (1 - pIn) : going ? -root.dir * pOut : 0) * art.slide / art.s
                                opacity: current ? Lib.phase(root.t, 0.08, 0.55) : going ? 1 - Lib.phase(root.t, 0, 0.4) : 0
                                source: {
                                    const a = root.steps[index].art;
                                    return Qt.resolvedUrl("Art" + a.charAt(0).toUpperCase() + a.slice(1) + ".qml");
                                }
                            }
                        }
                    }
                    // The miniatures are pictures: no hover, no clicks in them.
                    MouseArea { anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.AllButtons }
                }
                // The frame's rims: dark outside, light inside, as a pane of glass has.
                Rectangle {
                    anchors.fill: parent
                    radius: art.radius
                    color: "transparent"
                    border.width: Tokens.hairline
                    border.color: Qt.rgba(0, 0, 0, Colors.dark ? 0.35 : 0.12)
                }
                Rectangle {
                    anchors { fill: parent; margins: Tokens.hairline }
                    radius: art.radius - Tokens.hairline
                    color: "transparent"
                    border.width: Tokens.hairline
                    border.color: Qt.rgba(1, 1, 1, Colors.dark ? 0.12 : 0.4)
                }
            }

            // ------------------------------------------------------ text ---
            Item {
                id: textBox
                x: card.wide ? card.pad + card.artW + card.colGap : card.pad
                y: card.wide ? card.pad : card.pad + card.artH + card.pad
                width: card.width - x - card.pad
                height: card.wide ? card.artH : card.bodyH - card.artH - card.pad
                readonly property real slide: Tokens.gap * 4

                Repeater {
                    model: root.count
                    delegate: Item {
                        id: page
                        required property int index
                        readonly property var s: root.steps[index]
                        readonly property bool current: index === root.index
                        readonly property bool going: index === root.leaving
                        width: textBox.width; height: textBox.height
                        visible: card.visible && (current || going)
                        // Part k of the page: in, after the one before it.
                        function shown(k) {
                            if (going) return 1 - Lib.phase(root.t, 0, 0.3);
                            return Lib.phase(root.t, 0.14 + k * 0.07, 0.55) * Lib.phase(root.openT, 0.22 + k * 0.08, 0.45);
                        }
                        function shift(k) {
                            if (going) return -root.dir * Lib.phase(root.t, 0, 0.35) * textBox.slide * 0.6;
                            return root.dir * (1 - Lib.phase(root.t, 0.14 + k * 0.07, 0.55)) * textBox.slide;
                        }
                        function rise(k) { return going ? 0 : (1 - Lib.phase(root.openT, 0.22 + k * 0.08, 0.45)) * Tokens.gap * 1.5; }

                        Column {
                            id: words
                            width: parent.width
                            y: Math.max(0, (parent.height - height) * (card.wide ? 0.42 : 0))
                            spacing: Tokens.gap * 1.6

                            Row {
                                spacing: Tokens.gap
                                opacity: page.shown(0)
                                transform: Translate { x: page.shift(0); y: page.rise(0) }
                                // A short line of the tint's two hues.
                                Rectangle {
                                    width: Tokens.gap * 2.5; height: Tokens.hairline * 2; radius: Tokens.hairline
                                    anchors.verticalCenter: parent.verticalCenter
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0; color: Colors.accent }
                                        GradientStop { position: 1; color: Colors.accent2 }
                                    }
                                }
                                Label {
                                    text: Lib.eyebrow(page.index, root.count)
                                    role: "accent"; size: Tokens.textSmall
                                    font.weight: Font.DemiBold; font.letterSpacing: 1.6
                                }
                            }
                            Label {
                                width: parent.width
                                text: page.s.title
                                size: Math.round(Tokens.textTitle * 1.35)
                                font.weight: Font.DemiBold
                                font.letterSpacing: -0.4
                                wrapMode: Text.WordWrap; elide: Text.ElideNone
                                lineHeight: 1.05
                                opacity: page.shown(1)
                                transform: Translate { x: page.shift(1); y: page.rise(1) }
                            }
                            Label {
                                width: parent.width
                                text: page.s.body
                                role: "dim"
                                size: Tokens.textLarge
                                wrapMode: Text.WordWrap; elide: Text.ElideNone
                                lineHeight: 1.3
                                opacity: page.shown(2)
                                transform: Translate { x: page.shift(2); y: page.rise(2) }
                            }
                            // The step's keys, as caps, and what they do.
                            Row {
                                visible: page.s.keys.length > 0
                                spacing: Tokens.gap
                                opacity: page.shown(3)
                                transform: Translate { x: page.shift(3); y: page.rise(3) }
                                Row {
                                    spacing: Tokens.hairline * 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    Repeater {
                                        model: page.s.keys
                                        delegate: Keycap { required property string modelData; text: modelData; size: Tokens.textSize }
                                    }
                                }
                                Label { text: page.s.hint; role: "dim"; size: Tokens.textSmall + 1; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }
                }
            }

            // ---------------------------------------------------- footer ---
            Item {
                id: footer
                x: card.pad
                y: card.height - card.pad - height
                width: card.width - 2 * card.pad
                height: card.footerH
                readonly property real o: Lib.phase(root.openT, 0.45, 0.45)
                opacity: o
                transform: Translate { y: (1 - footer.o) * Tokens.gap * 1.5 }

                // The step marks, as the bar's workspaces: the current one lit
                // and wider; they glide as it moves. A click jumps there.
                Row {
                    id: marks
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property int mark: Math.round(card.u / 3)
                    spacing: 0
                    Repeater {
                        model: root.count
                        delegate: Item {
                            id: m
                            required property int index
                            readonly property bool on: index === root.index
                            readonly property bool seen: index < root.index
                            width: bead.width + Tokens.gap * 0.75
                            height: card.u
                            Rectangle {
                                id: bead
                                anchors.verticalCenter: parent.verticalCenter
                                height: marks.mark
                                width: m.on ? Math.round(marks.mark * 2.6) : marks.mark
                                radius: Tokens.radiusMark
                                color: m.on ? "transparent" : Colors.alpha(Colors.text, hit.containsMouse ? 0.4 : m.seen ? 0.3 : 0.1)
                                border.width: Tokens.hairline
                                border.color: m.on ? "transparent" : Colors.alpha(Colors.text, m.seen ? 0.38 : 0.24)
                                Behavior on width { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }
                                Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
                                ShellTint { anchors.fill: parent; radius: bead.radius; group: "overlay"; active: m.on }
                            }
                            MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.go(m.index) }
                        }
                    }
                }

                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: Tokens.gap
                    GlassButton {
                        visible: root.index < root.count - 1
                        group: "overlay"; level: 1; outlined: false
                        height: card.footerH
                        label: "Skip"
                        onClicked: root.finish()
                    }
                    GlassButton {
                        enabled: root.index > 0
                        group: "overlay"; level: 1; outlined: false
                        height: card.footerH
                        label: "Back"
                        onClicked: root.back()
                    }
                    GlassButton {
                        group: "overlay"; level: 1; outlined: false
                        height: card.footerH
                        width: Math.max(implicitWidth, Math.round(card.u * 3.6))
                        label: root.index >= root.count - 1 ? "Done" : "Next"
                        primary: true
                        onClicked: root.advance()
                    }
                }
            }
        }
    }
}
