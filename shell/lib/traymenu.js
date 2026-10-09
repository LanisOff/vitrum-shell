.pragma library
// The tray menu panel: what a DBus menu entry shows.

// "_Quit" → "Quit", "Save __as" → "Save _as": DBus menus mark the mnemonic
// with an underscore, and a doubled one is a literal underscore.
function label(text) {
    return String(text || "").replace(/__|_/g, function (m) { return m === "__" ? "_" : ""; });
}

// What sits at the row's far end: "submenu", "check" (a ticked checkbox or the
// chosen radio button), "none". buttonType: 0 none, 1 checkbox, 2 radio;
// checkState is Qt.CheckState (2 = checked).
function trailing(entry) {
    if (!entry) return "none";
    if (entry.hasChildren) return "submenu";
    if ((entry.buttonType === 1 || entry.buttonType === 2) && entry.checkState === 2) return "check";
    return "none";
}
