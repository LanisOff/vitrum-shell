pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/bar.js" as BarLib
import "../lib/games.js" as Games

/*
 * Everything the shell knows about the compositor.
 *
 * One long-lived `niri msg --json event-stream` is the source of truth;
 * it pushes state instead of us polling. Outputs come from `msg --json
 * outputs` (they do not change often; refreshed on a slow timer and when the
 * workspace set changes).
 *
 * If the compositor is not there (the shell started outside vitrum), the
 * stream fails, `available` stays false, and every consumer hides itself.
 */
Singleton {
    id: root

    readonly property string bin: Quickshell.env("VITRUM_NIRI") || "niri"

    property bool available: false

    /// id -> { id, title, appId, workspaceId, focused, floating, urgent, layout, focusTime }
    property var windows: ({})
    /// id -> { id, idx, name, output, active, focused, activeWindowId }
    property var workspaces: ({})
    /// name -> { name, x, y, width, height, scale }
    property var outputs: ({})
    property int focusedWindowId: -1
    property int focusedWorkspaceId: -1
    property bool overviewOpen: false
    property var keyboardLayouts: []
    property int keyboardLayoutIndex: 0
    readonly property string keyboardLayout: keyboardLayouts[keyboardLayoutIndex] || ""
    /// Short form for the bar: "English (US)" → "EN", "Russian" → "RU"
    readonly property string keyboardShort: {
        const l = keyboardLayout;
        if (!l) return "";
        const m = l.match(/\(([A-Z]{2})\)/);
        return (m ? m[1] : l.slice(0, 2)).toUpperCase();
    }

    readonly property var windowList: Object.values(windows)
    readonly property var workspaceList: {
        const l = Object.values(workspaces);
        l.sort((a, b) => (a.output === b.output ? (a.idx || 0) - (b.idx || 0) : (a.output < b.output ? -1 : 1)));
        return l;
    }
    readonly property var focusedWindow: windows[focusedWindowId] || null
    readonly property string focusedOutput: {
        const ws = workspaces[focusedWorkspaceId];
        return (ws && ws.output) ? ws.output : "";
    }

    /// The focused window when it covers its whole output, else null.
    readonly property var fullscreenWindow: {
        const w = focusedWindow;
        if (!w) return null;
        const ws = workspaces[w.workspaceId];
        return Games.isFullscreen(w, ws ? outputs[ws.output] : null) ? w : null;
    }

    signal windowOpened(var win)
    signal windowClosed(int id)

    // ---------------------------------------------------------- queries ---

    function workspacesOn(output) { return workspaceList.filter(w => w.output === output); }
    function activeWorkspaceOn(output) { return workspaceList.find(w => w.output === output && w.active) || null; }
    function windowsOn(wsId) { return windowList.filter(w => w.workspaceId === wsId); }

    /// The minimap of a workspace (shell/lib/bar.js).
    function columns(wsId, maxCols) { return BarLib.minimapColumns(windowList, wsId, maxCols || 8); }

    /// Tiles on an output's active workspace, in output-local logical
    /// coordinates (for the dock's intellihide).
    ///
    /// niri 26.04 reports an on-screen position only for floating windows;
    /// tiled ones come with their column and size. Columns span the working
    /// area's full height from its top, and their horizontal position is not
    /// reported — so a column is taken as a full-width band from `viewTop`
    /// down by its stacked tile heights. `viewTop` is where the working area
    /// starts (below a top bar).
    function tilesOn(output, viewTop) {
        const ws = activeWorkspaceOn(output);
        if (!ws) return [];
        const out = [], cols = {};
        const o = outputs[output];
        const fullW = o ? o.width : 100000;
        const gap = 0;
        for (const w of windowsOn(ws.id)) {
            const l = w.layout;
            if (!l || !l.tile_size) continue;
            if (l.tile_pos_in_workspace_view) {
                out.push({ x: l.tile_pos_in_workspace_view[0], y: l.tile_pos_in_workspace_view[1] + (viewTop || 0),
                           w: l.tile_size[0], h: l.tile_size[1], id: w.id });
            } else if (l.pos_in_scrolling_layout) {
                const c = l.pos_in_scrolling_layout[0];
                cols[c] = (cols[c] || 0) + l.tile_size[1];
            }
        }
        for (const c in cols) out.push({ x: 0, y: (viewTop || 0), w: fullW, h: cols[c] + gap, column: Number(c) });
        return out;
    }

    /// Most-recently-focused first. niri's timestamps are monotonic and
    /// debounced, so the focused window is put first explicitly.
    function windowsByRecency() {
        return windowList.slice().sort((a, b) => (b.focused - a.focused) || ((b.focusTime || 0) - (a.focusTime || 0)));
    }

    // ---------------------------------------------------------- commands ---

    function action(...args) {
        const p = actionComp.createObject(root, { command: [root.bin, "msg", "action"].concat(args.map(String)) });
        p.exited.connect(() => p.destroy());
        p.running = true;
    }
    Component { id: actionComp; Process {} }

    function windowPid(id)        { const w = windows[id]; return w ? w.pid : 0; }

    /// The desktop: the output's empty workspace (niri keeps one last), and
    /// back to where you were the next time.
    property int desktopFrom: -1
    function toggleDesktop() {
        const list = workspacesOn(focusedOutput);
        if (!list.length) return;
        const cur = workspaces[focusedWorkspaceId];
        if (cur && windowsOn(cur.id).length === 0 && workspaces[desktopFrom]) {
            focusWorkspace(workspaces[desktopFrom].idx);
            desktopFrom = -1;
        } else {
            desktopFrom = focusedWorkspaceId;
            focusWorkspace(list[list.length - 1].idx);
        }
    }

    /// Picture-in-picture players float in a corner (a window rule) and follow
    /// you from workspace to workspace on their screen (windows.pipFollows).
    readonly property var pipWindows: windowList.filter(w => /^(Picture-in-Picture|Picture in picture)$/.test(w.title || ""))
    onFocusedWorkspaceIdChanged: {
        const ws = workspaces[focusedWorkspaceId];
        if (!ws || !Settings.get("windows.pipFollows", true)) return;
        for (const w of pipWindows) {
            const at = workspaces[w.workspaceId];
            if (w.workspaceId !== ws.id && at && at.output === ws.output)
                action("move-window-to-workspace", "--window-id", String(w.id), "--focus", "false", String(ws.idx));
        }
    }
    function focusWindow(id)      { action("focus-window", "--id", id); }
    function closeWindow(id)      { action("close-window", "--id", id); }
    function focusWorkspace(idx)  { action("focus-workspace", idx); }
    function focusColumn(index)   { action("focus-column", index); }
    function toggleOverview()     { action("toggle-overview"); }
    function switchLayout(next)   { action("switch-layout", next ? "next" : "prev"); }
    function spawn(cmd)           { action.apply(root, ["spawn", "--"].concat(cmd)); }

    // ------------------------------------------------------ event stream ---

    Process {
        id: stream
        command: [root.bin, "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser { onRead: line => root._handleEvent(line) }
        onExited: (code, status) => { root.available = false; restart.restart(); }
    }
    Timer { id: restart; interval: 2000; onTriggered: stream.running = true }

    function _handleEvent(line) {
        if (!line || line.length === 0) return;
        let ev;
        try { ev = JSON.parse(line); } catch (e) { return; }
        available = true;

        if (ev.WindowsChanged) {
            const map = {};
            for (const w of ev.WindowsChanged.windows) map[w.id] = _mapWindow(w);
            windows = map;
            for (const w of Object.values(map)) if (w.focused) focusedWindowId = w.id;
        } else if (ev.WindowOpenedOrChanged) {
            const w = _mapWindow(ev.WindowOpenedOrChanged.window);
            const isNew = !windows[w.id];
            const map = Object.assign({}, windows);
            map[w.id] = w;
            if (w.focused) {
                for (const k in map) if (map[k].id !== w.id && map[k].focused) map[k] = Object.assign({}, map[k], { focused: false });
                focusedWindowId = w.id;
            }
            windows = map;
            if (isNew) windowOpened(w);
        } else if (ev.WindowClosed) {
            const id = ev.WindowClosed.id;
            const map = Object.assign({}, windows);
            delete map[id];
            windows = map;
            if (focusedWindowId === id) focusedWindowId = -1;
            windowClosed(id);
        } else if (ev.WindowFocusChanged) {
            focusedWindowId = ev.WindowFocusChanged.id === null ? -1 : ev.WindowFocusChanged.id;
            const map = Object.assign({}, windows);
            for (const k in map) map[k] = Object.assign({}, map[k], { focused: map[k].id === focusedWindowId });
            windows = map;
        } else if (ev.WindowFocusTimestampChanged) {
            const e = ev.WindowFocusTimestampChanged;
            if (windows[e.id]) {
                const map = Object.assign({}, windows);
                map[e.id] = Object.assign({}, map[e.id], { focusTime: _ts(e.focus_timestamp) });
                windows = map;
            }
        } else if (ev.WindowUrgencyChanged) {
            const e = ev.WindowUrgencyChanged;
            if (windows[e.id]) {
                const map = Object.assign({}, windows);
                map[e.id] = Object.assign({}, map[e.id], { urgent: e.urgent });
                windows = map;
            }
        } else if (ev.WindowLayoutsChanged) {
            const map = Object.assign({}, windows);
            for (const pair of ev.WindowLayoutsChanged.changes) {
                if (map[pair[0]]) map[pair[0]] = Object.assign({}, map[pair[0]], { layout: pair[1] });
            }
            windows = map;
        } else if (ev.WorkspacesChanged) {
            const map = {};
            for (const w of ev.WorkspacesChanged.workspaces) {
                map[w.id] = { id: w.id, idx: w.idx, name: w.name, output: w.output,
                              active: w.is_active, focused: w.is_focused, activeWindowId: w.active_window_id };
                if (w.is_focused) focusedWorkspaceId = w.id;
            }
            workspaces = map;
            outputsProc.running = true;
        } else if (ev.WorkspaceActivated) {
            const id = ev.WorkspaceActivated.id;
            const map = Object.assign({}, workspaces);
            // Every output has its own active workspace: only siblings on the same output change.
            const on = map[id] ? map[id].output : null;
            for (const k in map) {
                if (map[k].output !== on) continue;
                map[k] = Object.assign({}, map[k], { active: map[k].id === id });
            }
            if (ev.WorkspaceActivated.focused) {
                for (const k in map) map[k] = Object.assign({}, map[k], { focused: map[k].id === id });
                focusedWorkspaceId = id;
            }
            workspaces = map;
        } else if (ev.WorkspaceActiveWindowChanged) {
            const e = ev.WorkspaceActiveWindowChanged;
            if (workspaces[e.workspace_id]) {
                const map = Object.assign({}, workspaces);
                map[e.workspace_id] = Object.assign({}, map[e.workspace_id], { activeWindowId: e.active_window_id });
                workspaces = map;
            }
        } else if (ev.OverviewOpenedOrClosed) {
            overviewOpen = ev.OverviewOpenedOrClosed.is_open;
        } else if (ev.KeyboardLayoutsChanged) {
            const k = ev.KeyboardLayoutsChanged.keyboard_layouts;
            keyboardLayouts = k.names || [];
            keyboardLayoutIndex = k.current_idx || 0;
        } else if (ev.KeyboardLayoutSwitched) {
            keyboardLayoutIndex = ev.KeyboardLayoutSwitched.idx || 0;
        }
    }

    function _ts(t) {
        if (!t) return 0;
        // niri: { secs, nanos } on the monotonic clock — only compared with each other
        return (t.secs || 0) * 1000 + Math.floor((t.nanos || 0) / 1e6);
    }

    function _mapWindow(w) {
        return {
            id: w.id, title: w.title || "", appId: w.app_id || "", workspaceId: w.workspace_id,
            focused: !!w.is_focused, floating: !!w.is_floating, urgent: !!w.is_urgent, pid: w.pid || 0,
            layout: w.layout || null, focusTime: _ts(w.focus_timestamp)
        };
    }

    // ----------------------------------------------------------- outputs ---

    Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true; onTriggered: outputsProc.running = true }
    Process {
        id: outputsProc
        command: [root.bin, "msg", "--json", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const o = JSON.parse(text), map = {};
                    for (const name in o) {
                        const l = o[name].logical;
                        if (!l) continue;
                        map[name] = { name: name, x: l.x, y: l.y, width: l.width, height: l.height, scale: l.scale };
                    }
                    root.outputs = map;
                } catch (e) { /* not running */ }
            }
        }
    }
}
