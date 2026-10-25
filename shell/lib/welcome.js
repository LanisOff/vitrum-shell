.pragma library
// The welcome tour: what it says, and how its steps move.

// One step each. `art` names the illustration (modules/welcome/Art*.qml);
// keys are caps, as the keybind sheet shows them, and `hint` says what they do.
function steps() {
    return [
        { id: "bar", art: "bar", title: "The bar", keys: [], hint: "",
          body: "Workspaces on the left, the clock in the middle, the status icons on the right. Click the clock for your calendar, an icon for sound, network and more." },
        { id: "dock", art: "dock", title: "The dock", keys: [], hint: "",
          body: "Your pinned and running apps, one click away. It slips aside when a window needs the room, and comes back when the pointer touches the bottom edge." },
        { id: "search", art: "search", title: "Search everything", keys: ["Super", "Space"], hint: "opens search",
          body: "Apps, files, sums and your clipboard history, all from one field. Just start typing." },
        { id: "centre", art: "centre", title: "Control Centre", keys: ["Super", "Alt", "C"], hint: "or the bar's right end",
          body: "Volume, brightness, Wi-Fi, Bluetooth and the switches you reach for most, in one place." },
        { id: "widgets", art: "widgets", title: "Widgets", keys: ["Super", "Alt", "W"], hint: "opens the editor",
          body: "Put a clock, the weather or your system's vitals on the desktop. The editor adds, moves and resizes them." },
        { id: "settings", art: "settings", title: "Make it yours", keys: ["Super", ","], hint: "opens Settings",
          body: "Look, wallpaper, displays, sound, default apps and the keymap all live in Settings." },
        { id: "keys", art: "keys", title: "Every key at a glance", keys: ["Super", "/"], hint: "opens the sheet",
          body: "One sheet with every shortcut. Type in it to find the one you need." }
    ];
}

// The line over the title: a greeting on the first step, then where you are.
function eyebrow(i, n) {
    return i <= 0 ? "WELCOME TO VITRUM" : "STEP " + (i + 1) + " OF " + n;
}

// n means done.
function next(i, n) { return Math.min(i + 1, n); }
function prev(i) { return Math.max(i - 1, 0); }
// A jump (a click on a step mark): held to the steps there are.
function clampStep(i, n) { return Math.max(0, Math.min(n - 1, Math.round(i) || 0)); }

// One part of a staggered entrance: t runs 0 → 1 once for the whole, the part
// starts at `delay` and takes `span` of it, eased out (cubic, no overshoot).
function phase(t, delay, span) {
    var p = (t - (delay || 0)) / Math.max(0.0001, span || 1);
    p = Math.max(0, Math.min(1, p));
    return 1 - Math.pow(1 - p, 3);
}
