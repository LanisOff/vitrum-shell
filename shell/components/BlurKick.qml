import QtQuick
import Quickshell

/*
 * Makes sure niri gets a window's blur region after the window is (re)built.
 *
 *     BlurKick { id: blurKick; window: root }
 *     BackgroundEffect.blurRegion: Materials.wantsRegion("dock") && !blurKick.on ? effect : blurKick.none
 *
 * Quickshell rebuilds a layer-shell window on every map and screen change, and
 * its first polish runs before the Wayland surface exists — the pending blur
 * region is dropped there. With no region niri applies the layer rule to the
 * whole surface: a frosted band where only a plate should be, until the region
 * happens to change. Once the window shows, this sets the region to `none`
 * and back in one go, so Quickshell sends it again (and once more a moment later).
 *
 * `none` is what a window asks for when it wants no effect (a solid material,
 * a game running): a single pixel. Never null — no region at all is the whole
 * surface to niri, and a full-screen overlay would blur every screen.
 */
QtObject {
    id: kick
    required property var window
    property bool on: false
    readonly property Region none: Region { width: 1; height: 1 }
    function fire() { kick.on = true; kick.on = false; }
    property Connections _shown: Connections {
        target: kick.window
        function onBackingWindowVisibleChanged() {
            if (!kick.window.backingWindowVisible) return;
            Qt.callLater(kick.fire);
            kick._again.restart();
        }
    }
    property Timer _again: Timer { interval: 250; onTriggered: kick.fire() }
}
