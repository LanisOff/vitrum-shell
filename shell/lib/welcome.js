.pragma library
// The welcome tour: what it says, and how its steps move.

// One step each; keys are caps, as the keybind sheet shows them.
function steps() {
    return [
        { id: "bar", title: "The bar", keys: [],
          body: "The top bar holds the workspaces, the clock and the status icons. Click the clock for the calendar, the icons on the right for sound, network and more." },
        { id: "dock", title: "The dock", keys: [],
          body: "Your pinned and running apps live in the dock at the bottom. It slips away when a window needs the room, and comes back when the pointer touches the edge." },
        { id: "search", title: "Search", keys: ["Super", "Space"],
          body: "Type to find apps, files, a calculation or the clipboard history, all in one place." },
        { id: "centre", title: "The control centre", keys: [],
          body: "Open it from the right end of the bar: volume, brightness, Wi-Fi, Bluetooth and the switches you use most." },
        { id: "widgets", title: "Widgets", keys: ["Super", "Alt", "W"],
          body: "The desktop can carry widgets. This opens the editor, where you add, move and resize them." },
        { id: "settings", title: "Settings", keys: [],
          body: "Look, wallpaper, displays, sound, default apps and the keymap are all in Settings. Find it in search." },
        { id: "keys", title: "Every key at a glance", keys: ["Super", "/"],
          body: "This opens the sheet of all the keybinds. You can type in it to filter them." }
    ];
}

// n means done.
function next(i, n) { return Math.min(i + 1, n); }
function prev(i) { return Math.max(i - 1, 0); }
