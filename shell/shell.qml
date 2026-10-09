//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.components
import qs.modules.bar
import qs.modules.panels
import qs.modules.notifications
import qs.modules.launcher
import qs.modules.dock
import qs.modules.osd
import qs.modules.lock
import qs.modules.dialogs
import qs.modules.switcher
import qs.modules.capture
import qs.modules.desktop
import qs.modules.wallpaper
import qs.modules.overview
import qs.modules.keybinds
import qs.modules.screencast
import qs.modules.corners
import qs.modules.picker
import qs.ipc

/*
 * vitrum — the shell. Per-screen surfaces in Variants; single-instance ones
 * (they move to the focused output) below. Services are singletons, pulled
 * in by whoever needs them.
 */
ShellRoot {
    // No reload on file changes: the installer restarts the shell instead (a
    // reload under the lock screen destroys the lock surface and kills the shell).
    settings.watchFiles: false
    // Settings first; then what must run without being shown: hardware alerts,
    // the microphone filter (it comes back on at login when it was on), the
    // keyboard layout per app, calendar reminders.
    Component.onCompleted: { Settings.ready; HwAlerts.enabled; NoiseFilter.on; KeyboardMemory.on; Events.today; LoginScreen.dir; }

    // How long the start took, in the log: since this process began, and since
    // the session (niri) did.
    Process {
        running: true
        command: ["sh", "-c", 'tck=$(getconf CLK_TCK); up=$(cut -d" " -f1 /proc/uptime); ' +
                  'me=$(cut -d" " -f22 "/proc/$1/stat"); n=$(pgrep -o -x -u "$(id -u)" niri); ' +
                  'awk -v up="$up" -v me="$me" -v t="$tck" -v ni="$( [ -n "$n" ] && cut -d" " -f22 /proc/$n/stat )" ' +
                  '\'BEGIN { printf "vitrum: ready %d ms after the shell started", (up - me / t) * 1000; if (ni != "") printf ", %.1f s after niri", up - ni / t; print "" }\'',
                  "_", String(Quickshell.processId)]
        stdout: StdioCollector { onStreamFinished: console.info(text.trim()) }
    }

    Ipc { lockRef: lockScreen }

    Component { id: calendar; Calendar {} }
    Component { id: media; MediaPanel {} }
    Component { id: resources; Resources {} }
    Component { id: control; ControlCentre {} }
    Component { id: notificationsPanel; NotificationsPanel {} }
    Component { id: privacy; PrivacyPanel {} }
    Component { id: timers; TimersPanel {} }
    Component { id: updates; UpdatesPanel {} }
    Component { id: vitrumPanel; VitrumPanel {} }
    Component { id: trayMenu; TrayMenu {} }

    Lock { id: lockScreen }

    // A dock per screen, each fixed to it; only the focused screen's shows.
    // Not one dock that follows focus: a window that changes screens is
    // rebuilt by Quickshell, and on NVIDIA the rebuilt dock came up blurred
    // whole — a frosted band — until something moved.
    Variants {
        model: Quickshell.screens
        Scope {
            id: perScreen
            required property var modelData
            Dock {
                id: screenDock
                targetScreen: perScreen.modelData
                active: perScreen.modelData.name === (Niri.focusedOutput || (Quickshell.screens.length ? Quickshell.screens[0].name : ""))
            }
            DockEdge { dock: screenDock }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Scope {
            id: perScreen
            required property var modelData
            WallpaperView { modelData: perScreen.modelData }
            WallpaperPicker { modelData: perScreen.modelData }
            Desktop { modelData: perScreen.modelData }
            BarReserve { modelData: perScreen.modelData }
            Bar {
                modelData: perScreen.modelData
                panels: ({ calendar: calendar, media: media, resources: resources, control: control, privacy: privacy, timers: timers, updates: updates, vitrum: vitrumPanel, notifications: notificationsPanel, tray: trayMenu })
            }
            Toasts { modelData: perScreen.modelData }
            Launcher { modelData: perScreen.modelData }
            KeybindSheet { modelData: perScreen.modelData }
            ScreenSharePicker { modelData: perScreen.modelData }
            Osd { modelData: perScreen.modelData }
            PolkitDialog { modelData: perScreen.modelData }
            PowerMenu { modelData: perScreen.modelData }
            Switcher { modelData: perScreen.modelData }
            OverviewOverlay { modelData: perScreen.modelData }
            CaptureOverlay { modelData: perScreen.modelData }
            CaptureThumb { modelData: perScreen.modelData }
            ImageEditor { modelData: perScreen.modelData }
            Countdown { modelData: perScreen.modelData }
            HotCorners { modelData: perScreen.modelData }
            ColorPicker { modelData: perScreen.modelData }
            IdleDim { modelData: perScreen.modelData }
        }
    }
}
