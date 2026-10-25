//@ pragma AppId vitrum-about
//@ pragma Env VITRUM_NO_THEME=1
//@ pragma UseQApplication

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import qs.common
import "lib/about.js" as About

/*
 * About this computer, as spec tiles: the vitrum mark and the computer's name
 * on top, then glass tiles with what it is — processor, graphics, memory, the
 * root disk with a meter, time up, the screens as a little map with the
 * focused one lit, the board. Everything comes from the SysInfo service (the
 * shell's), turned into short words by lib/about.js, the vitrum version from
 * the installer. Unknown values say so instead of failing; long ones elide and
 * show whole in a tip under the pointer.
 *
 * Opening: the top rises in, then the tiles one after another, the disk's
 * meter fills from empty. Under the pointer a tile lifts 2 px with a faint
 * light under it; the two that open something (disk, screens) sink a little
 * when pressed. All damped, nothing loops, nothing moves without Motion.
 */
ShellRoot {
    id: app
    property string version: ""
    FileView {
        path: Quickshell.env("HOME") + "/.local/share/vitrum/version"
        onLoaded: app.version = text().trim()
        onLoadFailed: app.version = ""
    }
    Component.onCompleted: { SysInfo.refreshDisplays(); SysInfo.refreshDetails(); }

    // ------------------------------------------------------------ facts ----

    readonly property string gpuLine: About.gpuPick(SysInfo.gpuDevices || SysInfo.gpuModel)
    readonly property string cpuName: About.cpuShort(SysInfo.cpuModel)
    readonly property string cpuSub: SysInfo.cpuThreads ? (SysInfo.cpuCores ? SysInfo.cpuCores + " cores · " : "") + SysInfo.cpuThreads + " threads" : ""
    readonly property string gpuName: About.gpuShort(gpuLine)
    readonly property string gpuSub: [About.gpuVendor(gpuLine), About.vram(SysInfo.gpuVramMB)].filter(s => s).join(" · ")
    readonly property string memName: About.memory(SysInfo.memoryTotalGB)
    readonly property string memSub: About.memorySub(SysInfo.memoryType, SysInfo.memorySpeed || SysInfo.memoryDetail)
    readonly property string diskName: About.size(SysInfo.diskTotal)
    readonly property string diskSub: About.diskLine(SysInfo.diskUsed, SysInfo.diskFree)
    readonly property real diskUsage: About.diskUsage(SysInfo.diskUsed, SysInfo.diskUsed + SysInfo.diskFree)
    readonly property string upName: About.uptimeShort(SysInfo.uptimeSeconds) || SysInfo.uptime
    readonly property string upSub: SysInfo.packageCount ? SysInfo.packageCount + " packages" : ""
    readonly property string screensName: About.displaysLine(SysInfo.displays)
    readonly property string screensSub: About.displaysSub(SysInfo.displays)
    // The board: the mainboard's own name on a desktop, the product on a laptop.
    readonly property string boardRaw: SysInfo.boardName || SysInfo.boardModel
    readonly property string boardMaker: SysInfo.boardMaker || SysInfo.boardVendor
    readonly property string boardName: About.boardShort(boardRaw)
    readonly property string boardFull: About.boardFull(boardMaker, boardRaw)
    readonly property string boardSub: About.boardSub(boardMaker, SysInfo.biosVersion)
    readonly property string kernelLine: SysInfo.kernel ? "Linux " + SysInfo.kernel + (SysInfo.arch ? " · " + SysInfo.arch : "") : ""

    // What "Copy details" puts on the clipboard: the whole names, not the short ones.
    readonly property var rows: [
        { k: "System",     v: SysInfo.distro },
        { k: "Kernel",     v: SysInfo.kernel ? SysInfo.kernel + (SysInfo.arch ? " · " + SysInfo.arch : "") : "" },
        { k: "Processor",  v: SysInfo.cpuModel ? SysInfo.cpuModel + (SysInfo.cpuThreads ? " · " + SysInfo.cpuCores + " cores, " + SysInfo.cpuThreads + " threads" : "") : "" },
        { k: "Graphics",   v: gpuLine ? gpuLine + (SysInfo.gpuVramMB ? " · " + About.vram(SysInfo.gpuVramMB) : "") : "" },
        { k: "Memory",     v: memName ? memName + (memSub ? " · " + memSub : "") : "" },
        { k: "Storage",    v: diskName ? diskName + (diskSub ? " · " + diskSub : "") : "" },
        { k: "Display",    v: screensName ? screensName + (screensSub ? " · " + screensSub : "") : SysInfo.primaryDisplay },
        { k: "Board",      v: boardFull ? boardFull + (SysInfo.biosVersion ? " · firmware " + SysInfo.biosVersion : "") : "" },
        { k: "Up",         v: SysInfo.uptime },
        { k: "Packages",   v: SysInfo.packageCount ? String(SysInfo.packageCount) : "" },
        { k: "Compositor", v: SysInfo.niriVersion ? "niri " + SysInfo.niriVersion : "" },
        { k: "vitrum",     v: app.version }
    ]
    function report() {
        return [SysInfo.hostname].concat(rows.map(r => r.k + ": " + (r.v || "unknown"))).join("\n");
    }

    // ----------------------------------------------------------- pieces ----

    // Rises into place, `order` steps after the window opens. Damped (glide).
    component Entrance: SequentialAnimation {
        id: ent
        property Item item
        property QtObject shift
        property int order: 0
        PauseAnimation { duration: 60 + ent.order * 55 }
        ParallelAnimation {
            NumberAnimation { target: ent.shift; property: "y"; to: 0; duration: Motion.emphasized * 1.5; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.glide }
            NumberAnimation { target: ent.item; property: "opacity"; to: 1; duration: Motion.emphasized; easing.type: Easing.OutCubic }
        }
    }

    // One spec: a glass tile with a line icon in the accent and a small label,
    // a big value and a dim line under it, and room for more (a meter, a map).
    component SpecTile: Item {
        id: tile
        property string icon: "help"
        property string label: ""
        property string value: ""
        property string sub: ""
        /// The whole text for the tip, when the tile shows a short one.
        property string full: ""
        property int order: 0
        /// It opens something: the pointer is a hand and the tile sinks when pressed.
        property bool clickable: false
        signal activated()
        default property alias extra: more.data
        readonly property bool hovered: mouse.containsMouse
        readonly property bool pressed: mouse.pressed && clickable
        readonly property real pad: Tokens.padding * 1.2

        implicitHeight: body.implicitHeight + 2 * Tokens.padding
        // Above its neighbours while hovered: the tip and the light reach over them.
        z: hovered ? 5 : 0
        opacity: Motion.enabled ? 0 : 1
        transform: [
            Translate { id: rise; y: Motion.enabled ? 12 : 0 },
            Translate { y: tile.hovered && Motion.enabled ? -2 : 0; Behavior on y { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } } }
        ]
        scale: tile.pressed ? 0.97 : 1
        Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
        Entrance { id: inAnim; item: tile; shift: rise; order: tile.order }
        Component.onCompleted: if (Motion.enabled) inAnim.start()

        // The faint light under a hovered tile (CSS: 0 8px 18px −10px accent).
        Shape {
            id: glow
            readonly property real rx: tile.width * 0.46
            readonly property real k: 14 / Math.max(1, rx)
            width: 2 * rx; height: 2 * rx
            x: tile.width / 2 - rx
            y: tile.height - 2 - rx * k
            transform: Scale { yScale: glow.k }
            opacity: tile.hovered ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { enabled: Motion.enabled; NumberAnimation { duration: Motion.emphasized; easing.type: Easing.OutCubic } }
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                strokeWidth: 0
                fillGradient: RadialGradient {
                    centerX: glow.rx; centerY: glow.rx; centerRadius: glow.rx
                    focalX: glow.rx; focalY: glow.rx
                    GradientStop { position: 0; color: Colors.alpha(Colors.accent, Colors.dark ? 0.34 : 0.26) }
                    GradientStop { position: 0.55; color: Colors.alpha(Colors.accent, Colors.dark ? 0.12 : 0.09) }
                    GradientStop { position: 1; color: Colors.alpha(Colors.accent, 0) }
                }
                startX: 0; startY: glow.rx
                PathArc { x: 2 * glow.rx; y: glow.rx; radiusX: glow.rx; radiusY: glow.rx }
                PathArc { x: 0; y: glow.rx; radiusX: glow.rx; radiusY: glow.rx }
            }
        }
        Surface {
            anchors.fill: parent
            group: "panels"; level: 1
            radius: Tokens.radiusTile
        }
        // Under the pointer the glass clears a little and its rim brightens.
        Rectangle {
            anchors.fill: parent
            radius: Tokens.radiusTile
            color: Colors.alpha(Colors.text, tile.pressed ? 0.06 : tile.hovered ? 0.035 : 0)
            border.width: Tokens.hairline
            border.color: Colors.alpha(Colors.text, tile.hovered ? 0.10 : 0)
            Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.standard } }
            Behavior on border.color { enabled: Motion.enabled; ColorAnim { duration: Motion.standard } }
        }
        // The light on the top edge, fading out toward the corners.
        Rectangle {
            x: Tokens.radiusTile * 0.7; y: 1
            width: parent.width - 2 * x; height: 1
            opacity: tile.hovered ? 1 : 0.55
            Behavior on opacity { enabled: Motion.enabled; NumberAnimation { duration: Motion.standard; easing.type: Easing.OutCubic } }
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Colors.alpha(Colors.text, 0) }
                GradientStop { position: 0.5; color: Colors.alpha(Colors.text, Colors.dark ? 0.18 : 0.30) }
                GradientStop { position: 1; color: Colors.alpha(Colors.text, 0) }
            }
        }

        Column {
            id: body
            x: tile.pad; y: Tokens.padding
            width: tile.width - 2 * tile.pad
            spacing: Tokens.gap / 2
            Row {
                spacing: Tokens.gap * 0.75
                Icon { name: tile.icon; size: Tokens.iconSize; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                Label { text: tile.label; role: "dim"; size: Tokens.textSmall; anchors.verticalCenter: parent.verticalCenter }
            }
            Label {
                id: valueText
                width: body.width
                text: tile.value || "Unknown"
                role: tile.value ? "text" : "dim"
                size: Math.round(Tokens.textLarge * 1.2)
                font.weight: tile.value ? Font.DemiBold : Font.Normal
                numeric: true
            }
            Item { id: more; width: body.width; height: childrenRect.height; visible: children.length > 0 }
            Label {
                id: subText
                width: body.width
                visible: text.length > 0
                text: tile.sub
                role: "dim"
                size: Tokens.textSmall
                numeric: true
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: tile.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (tile.clickable) tile.activated()
        }
        // The whole text, when a line had to elide.
        Surface {
            readonly property bool show: tile.hovered && (valueText.truncated || subText.truncated || (tile.full.length > 0 && tile.full !== tile.value))
            z: 10
            group: "panels"; level: 2
            // Solid, as Sheet: an app window has no blur behind it, and the
            // glass let the name and the lines under the tip show through.
            color: Colors.bg
            radius: Tokens.radiusButton
            width: Math.min(tip.implicitWidth + 2 * Tokens.padding, Math.max(tile.width, 320))
            height: tip.implicitHeight + Tokens.padding
            x: Math.min(0, tile.width - width)
            y: -height - Tokens.gap / 2
            visible: opacity > 0
            opacity: show ? 1 : 0
            Behavior on opacity { enabled: Motion.enabled; NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
            Label {
                id: tip
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 2 * Tokens.padding)
                text: [tile.full || tile.value, tile.sub].filter(s => s).join("\n")
                size: Tokens.textSmall
                wrapMode: Text.Wrap
                elide: Text.ElideNone
            }
        }
    }

    // --------------------------------------------------------- the window --

    AppWindow {
        id: win
        appTitle: "About this computer"
        implicitWidth: 760
        implicitHeight: 560

        Flickable {
            id: flick
            anchors.fill: parent
            contentHeight: page.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Item {
                id: page
                x: Tokens.padding * 2
                width: flick.width - Tokens.padding * 4
                // At least the window: the buttons sit at the bottom right.
                height: Math.max(flick.height, natural)
                readonly property real natural: top.height + Tokens.gap * 2 + grid.height + Tokens.gap * 3 + buttons.height + Tokens.padding * 2

                // ---- the top: the mark, the name, what it runs ----
                Row {
                    id: top
                    y: Tokens.gap
                    spacing: Tokens.padding * 1.4
                    opacity: Motion.enabled ? 0 : 1
                    transform: Translate { id: topRise; y: Motion.enabled ? 12 : 0 }
                    Entrance { id: topIn; item: top; shift: topRise; order: 0 }
                    Component.onCompleted: if (Motion.enabled) topIn.start()

                    Gem {
                        width: Math.round(Tokens.islandHeight * 2.2); height: width
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Label {
                            text: SysInfo.hostname || "This computer"
                            size: Math.round(Tokens.textTitle * 1.3)
                            font.weight: Font.DemiBold
                            width: Math.min(implicitWidth, page.width - Tokens.islandHeight * 3)
                        }
                        Label {
                            text: About.subtitle(SysInfo.distro, SysInfo.niriVersion, app.version) || "Linux"
                            role: "dim"
                            width: Math.min(implicitWidth, page.width - Tokens.islandHeight * 3)
                        }
                        Label {
                            visible: text.length > 0
                            text: app.kernelLine
                            role: "dim"; size: Tokens.textSmall
                            width: Math.min(implicitWidth, page.width - Tokens.islandHeight * 3)
                        }
                    }
                }

                // ---- the tiles: three columns, the disk and the screens two wide ----
                Item {
                    id: grid
                    y: top.y + top.height + Tokens.gap * 2.5
                    width: page.width
                    readonly property real g: Tokens.gap
                    readonly property real cw: (width - 2 * g) / 3
                    function w(span) { return cw * span + g * (span - 1); }
                    function cx(col) { return col * (cw + g); }
                    readonly property real h0: Math.max(cpu.implicitHeight, gpu.implicitHeight, mem.implicitHeight)
                    readonly property real h1: Math.max(disk.implicitHeight, up.implicitHeight)
                    readonly property real h2: Math.max(screens.implicitHeight, board.implicitHeight)
                    readonly property real y1: h0 + g
                    readonly property real y2: y1 + h1 + g
                    height: y2 + h2

                    SpecTile {
                        id: cpu
                        x: grid.cx(0); width: grid.w(1); height: grid.h0
                        order: 1
                        icon: "cpu"; label: "Processor"
                        value: app.cpuName; full: SysInfo.cpuModel; sub: app.cpuSub
                    }
                    SpecTile {
                        id: gpu
                        x: grid.cx(1); width: grid.w(1); height: grid.h0
                        order: 2
                        icon: "gpu"; label: "Graphics"
                        value: app.gpuName; full: app.gpuLine.replace(/\s*\(rev [0-9a-f]+\)$/, ""); sub: app.gpuSub
                    }
                    SpecTile {
                        id: mem
                        x: grid.cx(2); width: grid.w(1); height: grid.h0
                        order: 3
                        icon: "memory"; label: "Memory"
                        value: app.memName; sub: app.memSub
                    }
                    SpecTile {
                        id: disk
                        x: grid.cx(0); y: grid.y1; width: grid.w(2); height: grid.h1
                        order: 4
                        icon: "disk"; label: "Storage"
                        value: app.diskName; sub: app.diskSub
                        clickable: true
                        onActivated: Quickshell.execDetached(["vitrum-disks"])
                        // Fills from empty once the tile is in.
                        property bool filled: !Motion.enabled
                        Timer { running: Motion.enabled; interval: 60 + 4 * 55 + Motion.standard; onTriggered: disk.filled = true }
                        Meter {
                            y: Tokens.gap / 4
                            width: parent.width
                            value: disk.filled ? app.diskUsage : 0
                            visible: SysInfo.diskTotal > 0
                        }
                    }
                    SpecTile {
                        id: up
                        x: grid.cx(2); y: grid.y1; width: grid.w(1); height: grid.h1
                        order: 5
                        icon: "clock"; label: "Up"
                        value: app.upName; full: SysInfo.uptime; sub: app.upSub
                    }
                    SpecTile {
                        id: screens
                        x: grid.cx(0); y: grid.y2; width: grid.w(2); height: grid.h2
                        order: 6
                        icon: "screen"; label: "Displays"
                        value: app.screensName; sub: app.screensSub
                        clickable: true
                        onActivated: Quickshell.execDetached(["vitrum-settings", "--pane", "displays"])
                        // The screens as niri lays them out, the focused one lit.
                        Item {
                            id: map
                            visible: SysInfo.displays.length > 0
                            y: Tokens.gap / 4
                            width: parent.width
                            height: mapBox.height + Tokens.textSmall + 6
                            Item {
                                id: mapBox
                                width: parent.width; height: Math.round(Tokens.islandHeight * 1.15)
                                // Laid out in a box at most six screens' heights wide, then moved to the left edge.
                                readonly property var rects: About.layout(SysInfo.displays, Math.min(width, height * 6), height, SysInfo.focusedOutput)
                                readonly property real left0: rects.length ? Math.min(...rects.map(r => r.x)) : 0
                                Repeater {
                                    model: mapBox.rects
                                    delegate: Item {
                                        id: scr
                                        required property var modelData
                                        x: modelData.x - mapBox.left0 + 1; y: modelData.y
                                        width: Math.max(4, modelData.width - 2); height: modelData.height
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Tokens.radiusKnob
                                            color: Colors.alpha(Colors.text, 0.07)
                                            border.width: Tokens.hairline
                                            border.color: Colors.alpha(Colors.text, 0.14)
                                        }
                                        ShellTint {
                                            anchors.fill: parent
                                            radius: Tokens.radiusKnob
                                            active: scr.modelData.primary
                                            hovered: screens.hovered
                                        }
                                        Label {
                                            parent: map
                                            x: scr.x; y: mapBox.height + 3
                                            width: scr.width
                                            horizontalAlignment: Text.AlignHCenter
                                            text: scr.modelData.name
                                            size: Tokens.textSmall - 1
                                            role: scr.modelData.primary ? "text" : "dim"
                                        }
                                    }
                                }
                            }
                        }
                    }
                    SpecTile {
                        id: board
                        x: grid.cx(2); y: grid.y2; width: grid.w(1); height: grid.h2
                        order: 7
                        icon: "board"; label: "Board"
                        value: app.boardName; full: app.boardFull; sub: app.boardSub
                    }
                }

                // ---- the actions, bottom right ----
                Row {
                    id: buttons
                    anchors { right: parent.right; bottom: parent.bottom; bottomMargin: Tokens.padding * 1.5 }
                    spacing: Tokens.gap
                    opacity: Motion.enabled ? 0 : 1
                    transform: Translate { id: btnRise; y: Motion.enabled ? 12 : 0 }
                    Entrance { id: btnIn; item: buttons; shift: btnRise; order: 8 }
                    Component.onCompleted: if (Motion.enabled) btnIn.start()

                    GlassButton {
                        id: copyBtn
                        height: Math.round(Tokens.islandHeight * 1.2)
                        width: implicitWidth
                        Behavior on width { enabled: Motion.enabled; SpringAnim { token: Motion.smooth } }
                        icon: copied.running ? "check" : "copy"
                        label: copied.running ? "Copied" : "Copy details"
                        onClicked: { Quickshell.execDetached(["wl-copy", "--", app.report()]); copied.restart(); }
                    }
                    GlassButton {
                        height: Math.round(Tokens.islandHeight * 1.2)
                        icon: "settings"
                        label: "Settings"
                        primary: true
                        onClicked: Quickshell.execDetached(["vitrum-settings"])
                    }
                    Timer { id: copied; interval: 1500 }
                }
            }
        }
    }
}
