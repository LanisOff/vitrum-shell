pragma Singleton

import QtQuick
import Quickshell

/*
 * What is open, and where. One panel (Control Centre, calendar, media,
 * resources) at a time, anchored to the island it came from; full-screen
 * surfaces (launcher, switcher, capture, power menu, centre) are exclusive.
 */
Singleton {
    id: root

    // Bar panels: name, the screen they belong to, the source island rect (window coords)
    property string panel: ""
    property var panelScreen: null
    property rect panelAnchor: Qt.rect(0, 0, 0, 0)
    /// The island a panel flows out of (null: the bar finds one that opens it).
    property var panelSource: null
    /// The tray item whose menu the "tray" panel shows.
    property var trayItem: null

    property bool launcher: false
    property bool centre: false
    property bool switcher: false
    property bool capture: false
    property bool power: false
    property bool widgetsEdit: false
    property bool wallpaperPicker: false
    signal widgetAddRequested(string type)
    property int widgetFramesMade: 0          // tests: frames created so far
    signal overviewQueryRequested(string text)     // vitrum-ipc debug overviewquery
    // Test hooks: the launcher follows launcherQuery and reports its first result.
    property string launcherQuery: ""
    property string launcherMode: ""          // "clipboard" opens in clipboard mode
    property string launcherFirst: ""
    property string launcherShowing: ""
    signal launcherRunFirst()                   // tests: Enter on the first result        // what the open launcher shows: "apps" | "clipboard" (tests)
    property string dockState: ""
    /// The keybind sheet (Mod+/).
    property bool keybinds: false
    /// A screen-share request from vitrum-portal: { id, types, multiple, app }, or null.
    property var screencastRequest: null
    signal screencastShareRequested(int index)      // vitrum-ipc debug screencastshare (tests)
    /// Debug IPC: each bar reports its state into barDebug on barProbe().
    signal barProbe()
    property var barDebug: ({})
    /// The focused screen's dock (debug IPC).
    property var activeDock: null
    signal osdRequested(string kind)
    signal switcherStep(int direction)
    signal switcherCommit()
    property bool locked: false
    /// Tests: the centre island shows the window title as if hovered.
    property bool debugHoverTitle: false
    /// Screen recording in progress (set by the capture module, T14).
    property bool recording: false
    signal stopRecordingRequested()
    function stopRecording() { stopRecordingRequested(); }

    function openPanel(name, screen, anchor, source) {
        if (panel === name && panelScreen === screen) { closePanel(); return; }
        closeOverlays();
        panelScreen = screen;
        panelAnchor = anchor;
        panelSource = source || null;
        panel = name;
    }
    function closePanel() { panel = ""; }

    function closeOverlays() { launcher = false; switcher = false; capture = false; power = false; wallpaperPicker = false; keybinds = false; }
    function toggle(name) {
        const was = root[name];
        closePanel(); closeOverlays();
        root[name] = !was;
    }
    function closeAll() { closePanel(); closeOverlays(); centre = false; }

    // The notification centre is the bar's "notifications" panel (it flows out
    // of the notifications island); `centre` stays the switch everything uses.
    onCentreChanged: {
        if (centre && panel !== "notifications") {
            const s = Quickshell.screens.find(x => x.name === Niri.focusedOutput) || Quickshell.screens[0];
            openPanel("notifications", s, Qt.rect(s.width - 80, 0, 60, 30), null);
        } else if (!centre && panel === "notifications") closePanel();
    }
    onPanelChanged: if (centre !== (panel === "notifications")) centre = panel === "notifications"

    readonly property bool anyOpen: panel !== "" || launcher || centre || switcher || capture || power || wallpaperPicker
}
