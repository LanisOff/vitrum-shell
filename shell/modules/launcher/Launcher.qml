import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components
import "../../lib/calc.js" as Calc
import "../../lib/timers.js" as TimerLib
import "../../lib/drop.js" as Drop
import "../../lib/spotlight.js" as Spot
import "../../lib/settings-panes.js" as Panes
import "../../lib/symbols.js" as Symbols

/*
 * Spotlight: a glass search capsule on the focused screen, with its
 * categories as round glass buttons beside it — Apps, Games, Clipboard, Emoji
 * & symbols. What it finds flows out of the capsule as a drop (as the bar's
 * panels flow out of their islands: niri's shaped glass melts the pieces into
 * one), a list on the left and a preview of the selected result on the right.
 *
 *   text        applications (usage-weighted fuzzy), settings, actions, games,
 *               open windows, SSH hosts, files, and a web search (Google)
 *   = 2^10      calculator          5 km to mi   conversion    10 usd to rub   money
 *   > cmd       run a command       : smile      emoji and symbols
 *   ? words     web search          5m           a timer       pomodoro
 *   Tab         the next category; arrows move, Enter runs, Escape closes
 *
 * The buttons drip out of the capsule as it opens and melt back as it closes.
 */
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property bool open: UiState.launcher && screen.name === (Niri.focusedOutput || Quickshell.screens[0].name)

    visible: true
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "vitrum-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ------------------------------------------------------------- state ---
    property var results: []
    property int current: 0
    property string query: ""
    /// "apps" | "games" | "clipboard" | "emoji"
    property string mode: "apps"
    readonly property var cats: [
        { m: "apps", i: "apps", t: "Apps" },
        { m: "games", i: "gamepad", t: "Games" },
        { m: "clipboard", i: "clipboard", t: "Clipboard" },
        { m: "emoji", i: "emoji", t: "Emoji & symbols" }
    ]
    function nextMode() {
        const i = cats.findIndex(c => c.m === mode);
        setMode(cats[(i + 1) % cats.length].m);
    }
    function setMode(m) { mode = m; current = 0; armedClear = false; refresh(); input.forceActiveFocus(); }
    readonly property bool gridMode: mode === "games" || mode === "emoji"
    readonly property int columns: mode === "games" ? 5 : 8

    // Steam games (tools/vitrum-steam), read when the launcher opens.
    property var games: []
    Process {
        id: steamProc
        command: ["vitrum-steam"]
        stdout: StdioCollector { onStreamFinished: { try { root.games = JSON.parse(text); } catch (e) { root.games = []; } if (root.open) root.refresh(); } }
    }
    function playGame(g) { Apps.runProc(["steam", "steam://rungameid/" + g.appid]); }
    function gameMatches(q) {
        const ql = q.toLowerCase();
        return games.filter(g => !ql || g.name.toLowerCase().indexOf(ql) >= 0);
    }

    // SSH hosts from ~/.ssh/config (not the wildcard patterns).
    property var sshHosts: []
    FileView {
        path: Quickshell.env("HOME") + "/.ssh/config"
        printErrors: false
        onLoaded: {
            const hosts = [];
            for (const line of text().split("\n")) {
                const m = line.match(/^\s*Host\s+(.+)$/i);
                if (!m) continue;
                for (const h of m[1].trim().split(/\s+/)) if (!/[*?!]/.test(h)) hosts.push(h);
            }
            root.sshHosts = hosts;
        }
    }

    // Exchange rates per USD, cached for 12 hours; fetched the first time money is asked for.
    property var rates: null
    readonly property string ratesFile: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/vitrum/rates.json"
    FileView {
        path: root.ratesFile
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { const d = JSON.parse(text()); root.rates = d.rates || null; root.ratesAt = d.time_last_update_unix || 0; } catch (e) {} if (root.open) root.refresh(); }
    }
    property real ratesAt: 0
    function fetchRates() {
        if (ratesProc.running || (rates && Date.now() / 1000 - ratesAt < 12 * 3600)) return;
        ratesProc.running = true;
    }
    Process {
        id: ratesProc
        command: ["sh", "-c", 'mkdir -p "$(dirname "$1")" && curl -fsSL --max-time 8 https://open.er-api.com/v6/latest/USD -o "$1.tmp" && mv -f "$1.tmp" "$1"', "_", root.ratesFile]
    }

    onOpenChanged: {
        if (open) {
            query = ""; input.text = ""; current = 0; armedClear = false;
            mode = ["clipboard", "games", "emoji"].indexOf(UiState.launcherMode) >= 0 ? UiState.launcherMode : "apps";
            UiState.launcherMode = "";
            if (!steamProc.running) steamProc.running = true;
            refresh(); input.forceActiveFocus(); Clipboard.refresh();
            // A query handed over (the emoji key) is used once.
            if (UiState.launcherQuery) { input.text = UiState.launcherQuery; UiState.launcherQuery = ""; }
            UiState.launcherShowing = mode;
        }
    }
    onQueryChanged: { current = 0; armedClear = false; refresh(); }
    onResultsChanged: if (open) UiState.launcherFirst = results.length ? results[0].title : ""
    onModeChanged: if (open) UiState.launcherShowing = mode
    Connections { target: UiState; function onLauncherQueryChanged() { if (root.open && UiState.launcherQuery) { input.text = UiState.launcherQuery; UiState.launcherQuery = ""; } } }
    Connections { target: Clipboard; function onEntriesChanged() { if (root.open && root.mode === "clipboard") root.refresh(); } }

    function run(r) { if (!r) return; if (r.keepOpen) { r.run(); return; } UiState.launcher = false; r.run(); }
    Connections { target: UiState; function onLauncherRunFirst() { if (root.open) root.run(root.results[0]); } }

    function copy(text) { Quickshell.execDetached(["wl-copy", "--", text]); }

    readonly property var actions: [
        { name: "Lock",            keys: "lock screen",            icon: "lock",     run: () => Power.lock() },
        { name: "Log out",         keys: "log out sign out quit",  icon: "logout",   run: () => UiState.toggle("power") },
        { name: "Suspend",         keys: "sleep suspend",          icon: "sleep",    run: () => Power.suspend() },
        { name: "Restart",         keys: "restart reboot",         icon: "restart",  run: () => UiState.toggle("power") },
        { name: "Power off",       keys: "shut down power off shutdown", icon: "power", run: () => UiState.toggle("power") },
        { name: "Settings",        keys: "settings preferences",   icon: "settings", run: () => Apps.runProc(["vitrum-settings"]) },
        { name: "Overview",        keys: "overview workspaces",    icon: "apps",     run: () => Niri.toggleOverview() },
        { name: "Light / dark",    keys: "dark light mode theme appearance", icon: "dark",
          run: () => Settings.set("scheme.mode", Colors.dark ? "light" : "dark") },
        { name: "Do not disturb",  keys: "do not disturb dnd focus", icon: "dnd",    run: () => Notifs.setDoNotDisturb(!Notifs.doNotDisturb) },
        { name: "Screenshot",      keys: "screenshot capture",     icon: "screenshot", run: () => Capture.open({ kind: "photo" }) },
        { name: "Colour picker",   keys: "color colour picker eyedropper pipette", icon: "colorize", run: () => ColorPick.start() },
        { name: "Pomodoro",        keys: "pomodoro focus timer",   icon: "hourglass", run: () => Timers.startPomodoro() },
        { name: "Wallpapers",      keys: "wallpaper background picker change choose", icon: "image", run: () => UiState.wallpaperPicker = true },
        { name: "Next wallpaper",  keys: "wallpaper background next", icon: "image", run: () => Wallpaper.cycle(1) },
        { name: "Edit widgets",    keys: "widgets desktop edit",   icon: "widgets",  run: () => UiState.widgetsEdit = true },
        { name: "Clear clipboard history", keys: "clear clipboard history wipe", icon: "clipboard", run: () => root.setMode("clipboard"), keepOpen: true }
    ]

    // Clearing the clipboard asks twice: Enter (or a click) arms it, the second goes.
    property bool armedClear: false

    // ----------------------------------------------------------- finding ---
    function appRow(a, group) { return { kind: "app", app: a, title: a.name, subtitle: a.genericName || a.comment || "", group: group, run: () => Apps.launch(a) }; }
    function emojiRows(q, limit) {
        const out = [];
        for (const e of Emoji.search(q).slice(0, limit))
            out.push({ kind: "emoji", glyph: e.char, title: e.name, group: "Emoji", run: () => { Emoji.use(e); copy(e.char); } });
        for (const s of Spot.searchSymbols(Symbols.all, q, limit))
            out.push({ kind: "emoji", glyph: s.char, title: s.name, group: s.group, run: () => copy(s.char) });
        return out;
    }

    function refresh() {
        const q = query.trim();
        const out = [];
        if (mode === "clipboard") {
            const found = Clipboard.search(q);
            if (Clipboard.entries.length > 0 && !q)
                out.push({ kind: "action", icon: "trash", group: "History",
                           title: armedClear ? "Press Enter again to clear everything" : "Clear the history",
                           subtitle: Clipboard.entries.length + (Clipboard.entries.length === 1 ? " entry" : " entries") + " · pictures and text",
                           keepOpen: true, run: () => { if (root.armedClear) { Clipboard.wipe(); root.armedClear = false; } else root.armedClear = true; root.refresh(); } });
            for (const e of found)
                out.push({ kind: "clip", entry: e, icon: e.isImage ? "image" : "clipboard",
                           title: e.isImage ? "Picture" : e.preview.replace(/\s+/g, " ").slice(0, 200), subtitle: e.isImage ? e.preview.replace(/^\[\[ binary data |\]\]$/g, "") : "",
                           group: "Clipboard", run: () => Clipboard.copy(e) });
        } else if (mode === "games") {
            for (const g of gameMatches(q))
                out.push({ kind: "game", game: g, title: g.name, subtitle: "Steam", group: "Games", run: () => playGame(g) });
        } else if (mode === "emoji") {
            // Nothing typed: every emoji; symbols come up when you name one.
            if (!q) for (const e of Emoji.all) out.push({ kind: "emoji", glyph: e.char, title: e.name, group: "Emoji", run: () => { Emoji.use(e); copy(e.char); } });
            else for (const r of emojiRows(q, 60)) out.push(r);
        } else if (TimerLib.parse(q) !== null) {
            const secs = TimerLib.parse(q);
            out.push({ kind: "timer", icon: "timer", title: "Start a " + TimerLib.label(secs), subtitle: "Counts down in the bar", group: "Timer", run: () => Timers.start(secs) });
        } else if (/^(pomodoro|помодоро)$/i.test(q)) {
            out.push({ kind: "timer", icon: "hourglass", title: "Start a pomodoro", subtitle: Settings.get("timers.work", 25) + " min of focus, then a break", group: "Timer", run: () => Timers.startPomodoro() });
        } else if (Calc.isCurrencyQuery(q)) {
            const v = Calc.convertCurrency(q, rates);
            if (v === null) fetchRates();
            const shown = v === null ? "…" : (Math.round(v * 100) / 100).toLocaleString(Qt.locale(), "f", 2);
            out.push({ kind: "calc", icon: "calculator", title: shown, subtitle: q + (v === null ? " · getting the rates" : ""), group: "Money",
                       run: () => { if (v !== null) copy(String(Math.round(v * 100) / 100)); } });
        } else if (q.startsWith("=") || Calc.looksLikeMath(q)) {
            const v = Calc.evaluate(q.replace(/^=/, ""));
            if (v !== null) {
                const shown = String(Math.round(v * 1e10) / 1e10);
                out.push({ kind: "calc", icon: "calculator", title: shown, subtitle: q.replace(/^=/, ""), group: "Calculator", run: () => copy(shown) });
            }
        } else if (Calc.convert(q) !== null) {
            const v = Calc.convert(q), shown = String(Math.round(v * 1e6) / 1e6);
            out.push({ kind: "calc", icon: "calculator", title: shown, subtitle: q, group: "Conversion", run: () => copy(shown) });
        } else if (q.startsWith(">")) {
            const cmd = q.slice(1).trim();
            if (cmd) {
                out.push({ kind: "command", icon: "terminal", title: cmd, subtitle: "Run it", group: "Command", run: () => Apps.runProc(["sh", "-c", cmd]) });
                out.push({ kind: "command", icon: "terminal", title: cmd, subtitle: "Run it in a terminal", group: "Command", run: () => Apps.runProc(["kitty", "--hold", "sh", "-c", cmd]) });
            }
        } else if (q.startsWith(":")) {
            for (const r of emojiRows(q.slice(1).trim(), 12)) out.push(r);
        } else if (q.startsWith("?")) {
            const w = q.slice(1).trim();
            if (w) out.push(webRow(w));
        } else if (q.length > 0) {
            const ql = q.toLowerCase();
            const apps = Apps.search(q, 8);
            if (apps.length) out.push(appRow(apps[0], "Top hit"));
            for (const a of apps.slice(1)) out.push(appRow(a, "Applications"));
            for (const p of Panes.find(q, 3))
                out.push({ kind: "pane", icon: p.icon, title: p.name, subtitle: "Settings", group: "Settings", run: () => Apps.runProc(["vitrum-settings", "--pane", p.id]) });
            for (const a of actions) {
                const n = a.name.toLowerCase();
                if (n.startsWith(ql) || a.keys.indexOf(ql) >= 0)
                    out.push({ kind: "action", icon: a.icon, title: a.name, subtitle: "System", group: "Actions", run: a.run, keepOpen: a.keepOpen });
            }
            for (const g of gameMatches(q).slice(0, 3))
                out.push({ kind: "game", game: g, title: g.name, subtitle: "Steam", group: "Games", run: () => playGame(g) });
            // Open windows: go to them.
            for (const w of Niri.windowsByRecency().filter(w => (w.title || "").toLowerCase().indexOf(ql) >= 0 || (w.appId || "").toLowerCase().indexOf(ql) >= 0).slice(0, 4))
                out.push({ kind: "window", app: Apps.forAppId(w.appId), icon: "window", title: w.title || w.appId, subtitle: Niri.workspaces[w.workspaceId] ? "Workspace " + Niri.workspaces[w.workspaceId].idx : "", group: "Windows", run: () => Niri.focusWindow(w.id) });
            // SSH hosts: "ssh name" or the name itself.
            const hq = ql.replace(/^ssh\s+/, "");
            for (const h of sshHosts.filter(h => hq && h.toLowerCase().indexOf(hq) >= 0).slice(0, 3))
                out.push({ kind: "ssh", icon: "terminal", title: "ssh " + h, subtitle: "Connect in a terminal", group: "SSH", run: () => Apps.runProc(["kitty", "-e", "ssh", h]) });
            files.ask(q);
            out.push(webRow(q));
        }
        results = out;
        if (current >= results.length) current = Math.max(0, results.length - 1);
    }

    function webRow(w) {
        return { kind: "web", icon: "web", title: "Search the web for “" + w + "”", subtitle: Settings.get("launcher.web", "").indexOf("google") >= 0 || !Settings.get("launcher.web", "") ? "Google" : "Web",
                 group: "Web", run: () => Apps.runProc(["xdg-open", Spot.webUrl(Settings.get("launcher.web", ""), w)]) };
    }

    // Files arrive later than everything else; they go in before the web row.
    QtObject {
        id: files
        property string pending: ""
        function ask(q) { if (q.length < 3) return; pending = q; proc.command = ["sh", "-c",
            "fd -i -H -d 6 --max-results 6 --exclude .git -- \"$1\" \"$HOME\" 2>/dev/null", "_", q]; proc.running = true; }
    }
    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                if (files.pending !== root.query.trim() || root.mode !== "apps") return;
                const rows = text.trim().split("\n").filter(s => s).map(p => ({
                    kind: "file", path: p, icon: Spot.fileKind(p) === "image" ? "image" : "file", title: p.split("/").pop(), subtitle: p.replace(Quickshell.env("HOME"), "~"),
                    group: "Files", run: () => Apps.runProc(["xdg-open", p]) }));
                if (!rows.length) return;
                const r = root.results.slice();
                r.splice(Math.max(0, r.length - 1), 0, ...rows);
                root.results = r;
            }
        }
    }

    function move(by) { current = Math.max(0, Math.min(results.length - 1, current + by)); }
    function key(e) {
        const cols = gridMode ? columns : 1;
        if (e.key === Qt.Key_Escape) { UiState.launcher = false; return true; }
        if (e.key === Qt.Key_Down) { move(cols); return true; }
        if (e.key === Qt.Key_Up) { move(-cols); return true; }
        if (gridMode && e.key === Qt.Key_Right && input.cursorPosition === input.text.length) { move(1); return true; }
        if (gridMode && e.key === Qt.Key_Left && input.cursorPosition === 0) { move(-1); return true; }
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            const r = results[current];
            if (r && r.kind === "file" && (e.modifiers & Qt.ControlModifier)) { UiState.launcher = false; Apps.runProc(["xdg-open", r.path.replace(/\/[^/]*$/, "") || "/"]); }
            else run(r);
            return true;
        }
        if (e.key === Qt.Key_Delete && mode === "clipboard") {
            const r = results[current];
            if (r && r.kind === "clip") { Clipboard.remove(r.entry); refresh(); }
            return true;
        }
        if (e.key === Qt.Key_Tab) { nextMode(); return true; }
        if (e.key === Qt.Key_Backtab) { const i = cats.findIndex(c => c.m === mode); setMode(cats[(i + cats.length - 1) % cats.length].m); return true; }
        return false;
    }

    // ---------------------------------------------------------- geometry ---
    readonly property bool shaped: Materials.shaped("launcher")
    readonly property real capH: Tokens.launcherHeight
    readonly property real capR: capH / 2
    readonly property real capW: Math.min(width - 2 * Tokens.gap - cats.length * (capH + Tokens.gap), Tokens.islandHeight * 20)
    readonly property real groupW: capW + cats.length * (capH + Tokens.gap)
    readonly property real gx: Math.round((width - groupW) / 2)
    readonly property real gy: Math.round(height * 0.18)

    // Appearing: 0 → 1 as it opens. The capsule swells from a drop in its
    // middle to its width, then the buttons drip out of its end; closing runs
    // it back once the results have drawn up — glass cannot fade, so it
    // shrinks away rather than leave a blank pane behind.
    property real shown: open ? 1 : 0
    Behavior on shown {
        id: shownAnim
        enabled: Motion.enabled
        SequentialAnimation {
            PauseAnimation { duration: shownAnim.targetValue < 0.5 && root.t > 0.05 ? Motion.standard : 0 }
            NumberAnimation { duration: shownAnim.targetValue > 0.5 ? Math.round(Motion.emphasized * 1.6) : Math.round(Motion.standard * 1.5); easing.type: Easing.Linear }
        }
    }
    readonly property bool alive: shown > 0.001
    function phase(a, b) { return Math.max(0, Math.min(1, (shown - a) / (b - a))); }
    function outCubic(v) { return 1 - Math.pow(1 - v, 3); }
    readonly property real grow: outCubic(phase(0, 0.55))
    readonly property real cw: capH + (capW - capH) * grow
    readonly property real cx: gx + (capW - cw) / 2
    readonly property real textOpacity: phase(0.4, 0.75)

    // The drop: there while something is to show.
    readonly property bool hasSheet: open && (query.trim().length > 0 || mode !== "apps") && sheetH > 1
    property real t: hasSheet ? 1 : 0
    Behavior on t {
        enabled: Motion.enabled
        NumberAnimation {
            duration: root.hasSheet ? Math.round(Motion.emphasized * 1.25) : Motion.standard
            easing.type: root.hasSheet ? Easing.OutBack : Easing.InOutCubic
            easing.overshoot: 1.05
        }
    }
    readonly property bool dropShown: t > 0.001 && alive

    readonly property real rowH: Tokens.islandHeight * 1.45
    readonly property real listW: gridMode && mode === "games" ? capW - 2 * Tokens.padding : Math.round((capW - 2 * Tokens.padding) * 0.56)
    // A grid cell, its gap included: exactly `columns` across.
    readonly property real cell: listW / columns - Tokens.gap * 0.5
    readonly property real gridRows: Math.min(mode === "games" ? 2 : 5, Math.ceil(results.length / columns))
    readonly property real contentH: gridMode
        ? (mode === "games" ? gridRows * (cell * 1.5 + Tokens.gap * 0.5) : gridRows * (cell + Tokens.gap * 0.5))
        : Math.min(list.contentHeight, rowH * 8.5)
    readonly property real sheetH: results.length === 0 ? (mode !== "apps" ? rowH * 2 : 0) : Math.max(contentH, mode === "games" ? 0 : rowH * 5) + 2 * Tokens.padding
    property real ah: sheetH
    Behavior on ah { enabled: Motion.enabled && root.t > 0.99; SpringAnim { token: Motion.smooth } }

    readonly property var capFrame: ({ x: gx, y: gy, w: capW, h: capH })
    // The results are as wide as the capsule and flow straight down out of it.
    readonly property var geo: Drop.dropGeometry(capFrame, { x: gx, w: capW, h: ah }, t, Tokens.gap)

    // ------------------------------------------------------------- input ---
    MouseArea { id: catcher; anchors.fill: parent; enabled: root.open; onClicked: UiState.launcher = false }
    Item { id: dot; width: 1; height: 1 }
    mask: Region { item: root.open ? catcher : dot }

    // -------------------------------------------------------- the glass ---
    // Shaped glass: plain rectangles, niri rounds and melts them. Otherwise
    // each piece is its own rounded region.
    Item { id: capItem; x: root.cx; y: root.gy; width: root.cw; height: root.capH; scale: Math.min(1, root.shown * 6); visible: root.alive }
    Item { id: neck; x: root.geo.neck.x; y: root.geo.neck.y; width: root.geo.neck.w; height: root.geo.neck.h }
    Item { id: sheet; x: root.geo.sheet.x; y: root.geo.sheet.y; width: root.geo.sheet.w; height: root.geo.sheet.h; visible: root.dropShown }

    Region { id: capRegion; item: capItem; radius: root.shaped ? 0 : root.capR }
    Region { id: neckRegion; item: neck }
    Region { id: sheetRegion; item: sheet; radius: root.shaped ? 0 : Math.min(root.capR, sheet.height / 2) }
    Region { id: dotRegion; item: dot }
    readonly property var catRegions: [cat0.region, cat1.region, cat2.region, cat3.region].filter(r => r)
    Region {
        id: effect
        regions: !root.alive ? [dotRegion]
               : [capRegion].concat(root.catRegions, !root.dropShown ? [] : root.shaped ? [neckRegion, sheetRegion] : [sheetRegion])
    }
    BlurKick { id: blurKick; window: root }
    BackgroundEffect.blurRegion: Materials.wantsRegion("launcher") && !blurKick.on ? effect : blurKick.none

    // The tint: along the drop's outline with shaped glass, else per piece.
    Shape {
        anchors.fill: parent
        visible: root.shaped && root.dropShown
        opacity: root.shown
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: Materials.fill("launcher", 0)
            PathSvg { path: root.shaped && root.dropShown ? Drop.dropPath(root.capFrame, root.geo.sheet, root.capR, root.capR, false, root.height) : "" }
        }
    }
    Rectangle {
        x: capItem.x; y: capItem.y; width: capItem.width; height: capItem.height
        scale: capItem.scale; visible: root.alive && !(root.shaped && root.dropShown)
        radius: root.capR
        color: Materials.fill("launcher", 0)
        border.width: root.shaped ? 0 : Tokens.hairline
        border.color: Materials.border("launcher")
    }
    Surface {
        x: sheet.x; y: sheet.y; width: sheet.width; height: sheet.height
        visible: root.dropShown && !root.shaped
        group: "launcher"
        radius: Math.min(root.capR, height / 2)
    }

    // --------------------------------------------------- the search field ---
    Item {
        x: capItem.x; y: capItem.y; width: capItem.width; height: capItem.height
        opacity: root.textOpacity; visible: root.alive
        clip: true
        MouseArea { anchors.fill: parent }
        Row {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding * 1.4; anchors.rightMargin: Tokens.padding * 1.4
            spacing: Tokens.gap
            Icon {
                id: lead
                name: root.cats.find(c => c.m === root.mode).i === "apps" ? "search" : root.cats.find(c => c.m === root.mode).i
                size: Tokens.iconSize * 1.25
                color: Colors.textDim
                anchors.verticalCenter: parent.verticalCenter
            }
            TextInput {
                id: input
                width: parent.width - lead.width - Tokens.gap
                anchors.verticalCenter: parent.verticalCenter
                font.family: Tokens.fontText
                font.pixelSize: Tokens.textLarge + 4
                color: Colors.text
                selectionColor: Colors.accent
                clip: true
                onTextChanged: root.query = text
                Keys.onPressed: e => { if (root.key(e)) e.accepted = true; }
                Label {
                    visible: input.text.length === 0
                    role: "dim"
                    size: Tokens.textLarge + 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.mode === "games" ? "Search your games" : root.mode === "clipboard" ? "Search the clipboard"
                        : root.mode === "emoji" ? "Search emoji and symbols" : "Spotlight Search"
                }
            }
        }
    }

    // ---------------------------------------------------- the categories ---
    // Round glass buttons beside the capsule; they drip out of it on opening.
    component Cat: Item {
        id: c
        required property int index
        readonly property var cat: root.cats[index]
        readonly property bool on: root.mode === cat.m
        readonly property real pop: root.outCubic(root.phase(0.45 + 0.08 * index, 0.8 + 0.08 * index))
        readonly property real home: root.gx + root.capW + Tokens.gap + index * (root.capH + Tokens.gap)
        readonly property real start: root.cx + root.cw - root.capH
        // From inside the capsule's right end out to its place.
        x: start + (home - start) * pop
        y: root.gy
        width: root.capH; height: root.capH
        visible: root.alive && pop > 0.01
        readonly property Region region: visible ? reg : null
        Region { id: reg; item: c; radius: root.shaped ? 0 : root.capR }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: c.on ? Colors.alpha(Colors.accent, 0.85) : m.containsMouse ? Colors.alpha(Colors.text, 0.16) : Materials.fill("launcher", 0)
            Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
            border.width: root.shaped ? 0 : Tokens.hairline
            border.color: Materials.border("launcher")
            opacity: c.pop
        }
        Icon { anchors.centerIn: parent; name: c.cat.i; color: c.on ? Colors.onAccent : Colors.text; opacity: c.pop; filled: c.on }
        scale: m.pressed ? 0.9 : 1
        Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
        MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setMode(c.cat.m) }
        ToolTipLabel { text: c.cat.t; shown: m.containsMouse }
    }
    Cat { id: cat0; index: 0 }
    Cat { id: cat1; index: 1 }
    Cat { id: cat2; index: 2 }
    Cat { id: cat3; index: 3 }

    // A small name under a button while it is hovered.
    component ToolTipLabel: Rectangle {
        property string text: ""
        property bool shown: false
        anchors.top: parent.bottom; anchors.topMargin: Tokens.gap * 0.6
        anchors.horizontalCenter: parent.horizontalCenter
        width: tl.implicitWidth + Tokens.gap * 1.5; height: tl.implicitHeight + Tokens.gap * 0.6
        radius: height / 2
        color: Colors.alpha(Colors.surfaceHighest, 0.92)
        opacity: shown && !root.dropShown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
        Label { id: tl; anchors.centerIn: parent; text: parent.text; size: Tokens.textSmall }
    }

    // ---------------------------------------------------------- the drop ---
    Item {
        id: content
        x: sheet.x; y: sheet.y; width: sheet.width; height: sheet.height
        visible: root.dropShown
        clip: true
        MouseArea { anchors.fill: parent }
        // Pinned to the far edge: the results come down out of the capsule.
        Item {
            id: inner
            x: Tokens.padding
            y: content.height - root.ah + Tokens.padding
            width: root.capW - 2 * Tokens.padding
            height: root.ah - 2 * Tokens.padding
            opacity: root.t > 0.5 ? Math.min(1, (root.t - 0.5) * 2.5) : 0

            // The list: grouped, the selection a pill that slides.
            ListView {
                id: list
                visible: !root.gridMode
                width: root.listW
                height: parent.height
                clip: true
                model: root.gridMode ? [] : root.results
                currentIndex: root.current
                boundsBehavior: Flickable.StopAtBounds
                // The selection: a pill that slides to the row (under its group's heading).
                highlightFollowsCurrentItem: false
                highlight: Rectangle {
                    width: list.width; height: root.rowH
                    radius: Tokens.radiusInner
                    color: Colors.alpha(Colors.accent, 0.24)
                    y: list.currentItem ? list.currentItem.y + list.currentItem.headH : 0
                    Behavior on y { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
                }
                add: Transition { enabled: Motion.enabled; NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.fast } }
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool selected: index === root.current
                    // The first of its group carries the group's name.
                    readonly property bool heads: index === 0 || (root.results[index - 1] || {}).group !== modelData.group
                    readonly property real headH: heads && modelData.group ? Tokens.textSmall * 2.2 : 0
                    width: list.width
                    height: root.rowH + headH
                    Label {
                        visible: row.headH > 0
                        width: parent.width; height: row.headH
                        verticalAlignment: Text.AlignBottom
                        leftPadding: Tokens.gap; bottomPadding: 2
                        text: row.modelData.group || ""; role: "dim"; size: Tokens.textSmall; font.weight: Font.DemiBold
                    }
                    HoverHandler { id: hover; onHoveredChanged: if (hovered) root.current = row.index }
                    TapHandler { onTapped: root.run(row.modelData) }
                    Row {
                        y: row.headH
                        x: Tokens.gap
                        width: parent.width - 2 * Tokens.gap; height: root.rowH
                        spacing: Tokens.gap
                        Item {
                            width: Tokens.iconSize * 1.6; height: width; anchors.verticalCenter: parent.verticalCenter
                            IconImage { anchors.fill: parent; visible: !!row.modelData.app; source: row.modelData.app ? Quickshell.iconPath(row.modelData.app.icon, "application-x-executable") : "" }
                            Image { anchors.fill: parent; visible: !!row.modelData.game; source: row.modelData.game && row.modelData.game.cover ? "file://" + row.modelData.game.cover : ""; fillMode: Image.PreserveAspectCrop; sourceSize.width: 64; asynchronous: true }
                            Icon { anchors.centerIn: parent; visible: !row.modelData.app && !row.modelData.glyph && !row.modelData.game; name: row.modelData.icon || "help"; color: row.selected ? Colors.accent : Colors.textDim }
                            Text { anchors.centerIn: parent; visible: !!row.modelData.glyph; text: row.modelData.glyph || ""; font.pixelSize: Tokens.iconSize * 1.2; color: Colors.text }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Tokens.iconSize * 1.6 - Tokens.gap
                            Label { width: parent.width; text: row.modelData.title; elide: Text.ElideRight; font.weight: row.selected ? Font.DemiBold : Font.Normal }
                            Label { width: parent.width; visible: text.length > 0; text: row.modelData.subtitle || ""; role: "dim"; size: Tokens.textSmall; elide: Text.ElideMiddle }
                        }
                    }
                }
            }

            // Games (covers) and emoji (glyphs): a grid.
            GridView {
                id: grid
                visible: root.gridMode
                width: root.listW
                height: parent.height
                clip: true
                cellWidth: root.cell + Tokens.gap * 0.5
                cellHeight: root.mode === "games" ? root.cell * 1.5 + Tokens.gap * 0.5 : root.cell + Tokens.gap * 0.5
                model: root.gridMode ? root.results : []
                currentIndex: root.current
                boundsBehavior: Flickable.StopAtBounds
                highlightFollowsCurrentItem: true
                highlightMoveDuration: Motion.enabled ? Motion.fast : 0
                highlight: Rectangle { radius: Tokens.radiusInner; color: "transparent"; border.width: 2; border.color: Colors.accent; z: 2 }
                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index
                    width: root.cell; height: root.mode === "games" ? root.cell * 1.5 : root.cell
                    HoverHandler { onHoveredChanged: if (hovered) root.current = tile.index }
                    TapHandler { onTapped: root.run(tile.modelData) }
                    scale: tile.index === root.current ? 1.04 : 1
                    Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.radiusInner
                        color: tile.index === root.current ? Colors.alpha(Colors.accent, 0.2) : Colors.alpha(Colors.text, 0.06)
                        clip: true
                        Image {
                            anchors.fill: parent
                            visible: !!tile.modelData.game
                            source: tile.modelData.game && tile.modelData.game.cover ? "file://" + tile.modelData.game.cover : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 300
                        }
                        Label {
                            visible: !!tile.modelData.game && !tile.modelData.game.cover
                            anchors.centerIn: parent; width: parent.width - Tokens.gap
                            text: tile.modelData.title; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !!tile.modelData.glyph
                            text: tile.modelData.glyph || ""
                            font.pixelSize: root.cell * 0.55
                            color: Colors.text
                        }
                    }
                }
            }

            Label {
                visible: root.results.length === 0
                anchors.centerIn: list
                text: root.mode === "games" ? (root.games.length ? "No game matches" : "No Steam games found")
                    : root.mode === "clipboard" ? (Clipboard.entries.length ? "Nothing matches" : "The clipboard history is empty")
                    : "Nothing found"
                role: "dim"
            }

            // The preview, right of the list.
            Rectangle {
                visible: root.mode !== "games"
                x: root.listW + Tokens.padding * 0.5
                width: Tokens.hairline; height: parent.height
                color: Colors.alpha(Colors.text, 0.1)
            }
            LauncherPreview {
                visible: root.mode !== "games"
                x: root.listW + Tokens.padding
                width: parent.width - x
                height: parent.height
                item: root.results.length ? root.results[root.current] || null : null
            }
        }
    }
}
