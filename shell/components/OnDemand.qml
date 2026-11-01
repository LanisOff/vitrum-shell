import QtQuick
import Quickshell

/*
 * A window built when it is wanted, and thrown away a while after.
 *
 *     OnDemand { want: UiState.keybinds && perScreen.focused; KeybindSheet { ... } }
 *
 * An unmapped window is only half gone: Quickshell deletes the surface, but the
 * QML tree under it stays in memory and keeps following its bindings. So a
 * window that is rarely open lives here, and exists only from the moment it is
 * wanted until `keep` after the last time it was. Opening it again within that
 * time is as quick as ever.
 *
 * The window has `gate.ready` in its `open` (components/MapGate.qml), and `want`
 * says the same as its `open` without that: `open` is false while the window is
 * being built and turns true a tick later, so onOpenChanged runs and the
 * entrance animates. `want` must not be narrower than `open`, or it never opens.
 *
 * Only for a window that nothing has to reach while it is closed: it must not
 * be the one that decides it opens (Switcher handles its own key), and a service
 * only it refers to starts with it. What must run from the start goes in
 * shell.qml's Component.onCompleted.
 *
 * `keep` also outlasts the exit animation by far, so the window is never
 * deleted while it is still mapped.
 */
LazyLoader {
    id: lazy
    /// The window is wanted now.
    property bool want: false
    /// How long it stays after that, in ms.
    property int keep: 60000
    property bool kept: false

    active: want || kept
    // `kept` goes up with `want` and comes down only by the timer, so `active`
    // never dips between the two.
    onWantChanged: {
        if (want) { keepTimer.stop(); kept = true; }
        else keepTimer.restart();
    }
    Component.onCompleted: if (want) kept = true

    property Timer keepTimer: Timer {
        interval: lazy.keep
        onTriggered: lazy.kept = false
    }
}
