pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * The widgets people make themselves, as catalog entries by type:
 *   script:<id>   widgets.custom in settings — a command, how often, a template
 *   qml:<folder>  ~/.config/vitrum/widgets/<folder>/ — manifest.json and Widget.qml
 * Each entry is what W.meta wants: { name, icon, sizes, def, options, interactive }.
 * The folders are read at start, when the editor opens, and on reload().
 */
Singleton {
    id: root

    /// widgets.custom: [{ id, name, icon, command, interval, template }]
    readonly property var scripts: (Settings.get("widgets.custom", []) || []).filter(s => s && typeof s.id === "string" && /^[\w-]+$/.test(s.id))
    readonly property var entries: {
        const out = {};
        for (const s of scripts)
            out["script:" + s.id] = { name: s.name || "Script", icon: s.icon || "code", sizes: ["S", "M", "L"], def: "M", options: [], script: s };
        for (const f in qml) out["qml:" + f] = qml[f];
        return out;
    }

    // ---------------------------------------------------------- folders ---
    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/vitrum/widgets"
    /// folder → its manifest (as an entry), for the folders with both files.
    property var qml: ({})
    function reload() { if (!scan.running) scan.running = true; }
    Component.onCompleted: reload()
    Connections { target: UiState; function onWidgetsEditChanged() { if (UiState.widgetsEdit) root.reload(); } }
    Process {
        id: scan
        command: ["sh", "-c", 'for d in "$1"/*/; do [ -f "$d/manifest.json" ] && [ -f "$d/Widget.qml" ] || continue; printf "%s\t%s\n" "$(basename "$d")" "$(tr -d "\n\t" < "$d/manifest.json")"; done', "_", root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab <= 0) continue;
                    const folder = line.slice(0, tab);
                    if (!/^[\w.-]+$/.test(folder)) continue;
                    let m;
                    try { m = JSON.parse(line.slice(tab + 1)); } catch (e) { m = { name: folder + " (manifest.json is not valid JSON)" }; }
                    if (!m || typeof m !== "object") continue;
                    // Only well-formed options; choices that are no list are dropped, not trusted.
                    const options = Array.isArray(m.options) ? m.options.filter(o => o && typeof o.key === "string" && typeof o.label === "string" && typeof o.type === "string")
                        .map(o => Array.isArray(o.choices) || o.choices === undefined ? o : Object.assign({}, o, { choices: undefined })) : [];
                    out[folder] = { name: String(m.name || folder), icon: String(m.icon || "code"), sizes: Array.isArray(m.sizes) ? m.sizes : [],
                                    def: m.def, options: options, interactive: !!m.interactive, folder: folder };
                }
                root.qml = out;
            }
        }
    }
    function script(id) { return scripts.find(s => s.id === id) || null; }
    /// Add or replace one (by id) in widgets.custom.
    function saveScript(s) {
        const list = scripts.filter(x => x.id !== s.id).concat([s]);
        Settings.set("widgets.custom", list);
    }
    function deleteScript(id) { Settings.set("widgets.custom", scripts.filter(x => x.id !== id)); }
}
