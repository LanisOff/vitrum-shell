.pragma library
// Lite mode: which of the heavy effects are cut, from the settings' lite block
// and the machine's state. The shell's Lite service binds to resolve(); and
// vitrum-theme (tools/vitrum_theme lite_flags) folds in the same rules for
// niri, from the reason the shell writes to ~/.local/share/vitrum/lite.
//
//   lite   the settings' lite block: enabled, one switch per part, auto { … }
//   st     { hasBattery, pluggedIn, percentage (0..100), saver (power-saver profile) }

// One switch per part; true means the part is cut.
var PARTS = ["blur", "glass", "light", "animations", "windowAnimations", "shadows", "wallpaper", "spectrum", "windowGlass", "polling"];

// The parts niri draws: they reach it through vitrum-theme, a moment after the shell.
var NIRI_PARTS = ["blur", "glass", "windowAnimations", "shadows", "windowGlass"];

// How much slower the system figures are read with polling cut.
var SLOW = 3;

function _on(v) { return v === true; }

// Why lite mode turns itself on: "battery" (on battery), "low" (on battery,
// at or below auto.below %), "saver" (the Saver power profile), or "".
// On battery means a battery and no charger: a desktop never is.
function automatic(lite, st) {
    var a = (lite && lite.auto) || {};
    var s = st || {};
    var onBattery = s.hasBattery === true && s.pluggedIn === false;
    if (onBattery && _on(a.onBattery)) return "battery";
    var below = typeof a.below === "number" ? a.below : 30;
    if (onBattery && _on(a.lowBattery) && typeof s.percentage === "number" && s.percentage <= below) return "low";
    if (s.saver === true && _on(a.powerSaver)) return "saver";
    return "";
}

// → { active, reason, cut: { part: bool } }. reason: "manual" (the master
// switch), an automatic one, or "" (off). With lite mode active every part is
// cut; off, a part is cut when its own switch is on.
function resolve(lite, st) {
    var l = lite || {};
    var reason = _on(l.enabled) ? "manual" : automatic(l, st);
    var active = reason !== "";
    var cut = {};
    for (var i = 0; i < PARTS.length; i++) cut[PARTS[i]] = active || _on(l[PARTS[i]]);
    return { active: active, reason: reason, cut: cut };
}

// What the shell writes for vitrum-theme: the automatic reason ("" when lite
// mode is off or the master switch holds it: vitrum-theme reads that from
// the settings itself).
function stateText(r) {
    return (r && r.reason && r.reason !== "manual" ? r.reason : "") + "\n";
}

// A polling interval, slower with polling cut.
function interval(ms, slow) { return slow ? ms * SLOW : ms; }

// The line the Settings pane shows while lite mode holds every switch.
function heldText(reason) {
    if (reason === "manual") return "On with lite mode.";
    if (reason === "battery") return "On: lite mode is on while on battery.";
    if (reason === "low") return "On: lite mode is on while the battery is low.";
    if (reason === "saver") return "On: lite mode is on with the Saver profile.";
    return "";
}
