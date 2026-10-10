.pragma library
// The Settings app's sections — one list for the app (sidebar, its search,
// --pane) and for Spotlight (sections as actions).
//   id       what --pane takes; the page is panes/<Id>Pane.qml
//   keys     setting-key prefixes the section holds (the app's search)
//   words    what people look for it by (Spotlight)
//   aliases  old ids that still open it

var panes = [
    { group: "Personal", id: "appearance", name: "Appearance", icon: "palette", keys: ["scheme", "palette", "density", "toolkits"], words: "theme dark light colours colors accent density scheme gtk kde" },
    { group: "Personal", id: "wallpaper", name: "Wallpaper", icon: "image", keys: ["wallpaper"], words: "background picture day night video live parallax" },
    { group: "Personal", id: "materials", name: "Materials", icon: "materials", keys: ["materials"], words: "glass blur frosted transparency" },
    { group: "Personal", id: "type", name: "Fonts & icons", icon: "typography", keys: ["fonts", "icons", "cursor"], words: "font fonts typography text size scale icons cursor" },
    { group: "Personal", id: "motion", name: "Motion", icon: "motion", keys: ["motion"], words: "animation speed reduce motion" },
    { group: "Desktop", id: "bar", name: "Bar", icon: "toolbar", keys: ["bar"], words: "panel top islands modules" },
    { group: "Desktop", id: "dock", name: "Dock", icon: "apps", keys: ["dock"], words: "taskbar icons magnify pinned" },
    { group: "Desktop", id: "widgets", name: "Widgets", icon: "widgets", keys: ["widgets"], words: "desktop clock weather" },
    { group: "Desktop", id: "notifications", name: "Notifications", icon: "notifications", keys: ["notifications", "sounds.notification"], words: "do not disturb dnd toasts" },
    { group: "Desktop", id: "windows", name: "Windows", icon: "window", keys: ["windows", "terminal"], words: "focus opacity terminal materials pip picture" },
    { group: "Desktop", id: "navigation", name: "Navigation", icon: "search", keys: ["launcher", "switcher", "overview", "clipboard", "corners"], words: "spotlight launcher search alt tab switcher overview clipboard hot corners web", aliases: ["search"] },
    { group: "Desktop", id: "capture", name: "Screenshots & recording", icon: "screenshot", keys: ["capture", "screencast", "picker"], words: "screen recording capture share colour picker text recognition" },
    { group: "System", id: "sound", name: "Sound", icon: "volume-high", keys: ["audio", "sounds"], words: "audio volume speakers microphone output input noise sounds" },
    { group: "System", id: "media", name: "Media", icon: "music", keys: ["media"], words: "music player lyrics spectrum visualizer" },
    { group: "System", id: "network", name: "Network", icon: "wifi", keys: [], words: "wifi wi-fi ethernet internet vpn" },
    { group: "System", id: "bluetooth", name: "Bluetooth", icon: "bluetooth", keys: [], words: "headphones devices pair" },
    { group: "System", id: "displays", name: "Displays", icon: "screen", keys: [], words: "monitor resolution refresh rate scale vrr brightness" },
    { group: "System", id: "keyboard", name: "Keyboard & shortcuts", icon: "keyboard", keys: ["keyboard", "keybinds"], words: "layout keys shortcuts bindings" },
    { group: "System", id: "input", name: "Mouse & touchpad", icon: "mouse", keys: ["input"], words: "mouse touchpad pointer sensitivity speed acceleration scroll natural tap trackpad" },
    { group: "System", id: "lock", name: "Lock & idle", icon: "lock", keys: ["lock"], words: "lock screen lock after idle dim after screen off sleep picture face" },
    { group: "System", id: "power", name: "Power & performance", icon: "power", keys: ["awake", "games", "alerts"], words: "battery profile performance game mangohud awake temperature alerts" },
    { group: "System", id: "time", name: "Date & time", icon: "calendar", keys: ["clock", "weather", "timers", "calendar"], words: "clock date time zone weather pomodoro calendar" },
    { group: "System", id: "advanced", name: "Advanced", icon: "settings", keys: ["updates"], words: "advanced debug reset json update version vitrum" }
];

function _byId(id) {
    for (var i = 0; i < panes.length; i++) {
        var p = panes[i];
        if (p.id === id || (p.aliases || []).indexOf(id) >= 0) return p;
    }
    return null;
}
function known(id) { return _byId(String(id || "")) !== null; }
function resolve(id) { var p = _byId(String(id || "")); return p ? p.id : "appearance"; }
function paneFile(id) { return "panes/" + id.charAt(0).toUpperCase() + id.slice(1) + "Pane.qml"; }

// The app's search: the section's name, its words, or the label of a setting
// it holds (keys: every setting key; label(key) → its label).
function matches(p, q, keys, label) {
    var ql = String(q || "").toLowerCase().trim();
    if (!ql) return true;
    if (p.name.toLowerCase().indexOf(ql) >= 0) return true;
    if ((" " + p.words).indexOf(" " + ql) >= 0) return true;
    for (var i = 0; i < keys.length; i++) {
        var k = keys[i];
        for (var j = 0; j < p.keys.length; j++) {
            var pre = p.keys[j];
            if ((k === pre || k.indexOf(pre + ".") === 0) && String(label(k)).toLowerCase().indexOf(ql) >= 0) return true;
        }
    }
    return false;
}

// Spotlight: names that begin with it, then names holding it, then words.
function find(q, limit) {
    var ql = String(q || "").toLowerCase().trim();
    if (ql.length < 2) return [];
    var lead = [], byName = [], byWord = [];
    for (var i = 0; i < panes.length; i++) {
        var p = panes[i], n = p.name.toLowerCase();
        if (n.indexOf(ql) === 0) lead.push(p);
        else if (n.indexOf(ql) >= 0) byName.push(p);
        else if ((" " + p.words).indexOf(" " + ql) >= 0) byWord.push(p);
    }
    return lead.concat(byName, byWord).slice(0, limit);
}
