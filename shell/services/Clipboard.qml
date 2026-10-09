pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Clipboard history, backed by cliphist.
 *
 * cliphist stores an id-prefixed line per entry; the id is what you feed back
 * to `cliphist decode` to restore it, including for images. We keep the
 * decoded preview lazy so opening the panel does not decode a hundred PNGs.
 */
Singleton {
    id: root

    property var entries: []          // [{ id, preview, isImage }]
    property bool available: true

    function refresh() { list.running = true; }

    Process {
        id: list
        // The whole history (vitrum-clip keeps text for good): the launcher's
        // list is lazy, and searching a few thousand lines is instant.
        // Longer previews than cliphist's 100 characters: search sees more of each.
        command: ["sh", "-c", "cliphist -preview-width 400 list 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (!line) continue;
                    const tab = line.indexOf("\t");
                    if (tab < 0) continue;
                    const id = line.substring(0, tab);
                    const preview = line.substring(tab + 1);
                    out.push({
                        id: id,
                        preview: preview,
                        // cliphist marks binary entries with this shape.
                        isImage: /^\[\[ binary data .* (png|jpe?g|gif|webp|bmp) /i.test(preview)
                    });
                }
                root.entries = out;
            }
        }
        onExited: code => { if (code !== 0) root.available = false; }
    }

    // ------------------------------------------------------- previews ---
    // A picture entry is decoded once to a file; a text entry is decoded whole
    // (the list holds only its first few hundred characters). Asked for by the
    // launcher's preview when the selection moves, never from a binding.
    readonly property string cacheDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/vitrum-clip"
    property var decoded: ({})        // id → picture file, once written
    property var failed: ({})         // ids that would not decode: not tried again
    property string fullId: ""
    property string fullText: ""      // the whole text of fullId
    function requestPreview(entry) {
        if (!entry || failed[entry.id]) return;
        if (entry.isImage) {
            if (decoded[entry.id] || decoder.running) return;
            decoder.wanted = entry.id;
            decoder.command = ["sh", "-c", 'umask 077; mkdir -p "$1" && cliphist decode "$2" > "$1/$2.img.tmp" && mv -f "$1/$2.img.tmp" "$1/$2.img" || { rm -f "$1/$2.img.tmp"; exit 1; }', "_", cacheDir, entry.id];
            decoder.running = true;
        } else if (fullId !== entry.id) {
            fullId = entry.id; fullText = "";
            textDecoder.running = false;
            textDecoder.command = ["sh", "-c", 'cliphist decode "$1" | head -c 20000', "_", entry.id];
            textDecoder.running = true;
        }
    }
    function imagePath(entry) { return entry && decoded[entry.id] ? decoded[entry.id] : ""; }
    Process {
        id: decoder
        property string wanted: ""
        onExited: code => {
            const ok = code === 0;
            const d = Object.assign({}, ok ? root.decoded : root.failed);
            d[wanted] = ok ? root.cacheDir + "/" + wanted + ".img" : true;
            if (ok) root.decoded = d; else root.failed = d;
        }
    }
    Process {
        id: textDecoder
        stdout: StdioCollector { onStreamFinished: root.fullText = text }
    }
    function _forget(id) {
        Quickshell.execDetached(["rm", "-f", cacheDir + "/" + id + ".img"]);
        const d = Object.assign({}, decoded); delete d[id]; decoded = d;
    }

    /// Put an entry back on the clipboard.
    function copy(entry) {
        Quickshell.execDetached(["sh", "-c", "cliphist decode " + _q(entry.id) + " | wl-copy"]);
    }

    function remove(entry) {
        Quickshell.execDetached(["sh", "-c", "printf '%s\\t%s' " + _q(entry.id) + " " + _q(entry.preview) + " | cliphist delete"]);
        entries = entries.filter(e => e.id !== entry.id);
        _forget(entry.id);
    }

    function wipe() {
        Quickshell.execDetached(["rm", "-rf", cacheDir]);
        decoded = ({}); failed = ({}); fullId = ""; fullText = "";
        proc.command = ["cliphist", "wipe"];
        proc.running = true;
        entries = [];
    }

    function search(query) {
        if (!query) return entries;
        const q = query.toLowerCase();
        return entries.filter(e => e.preview.toLowerCase().indexOf(q) >= 0);
    }

    function _q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

    Process {
        id: proc
        onExited: root.refresh()
    }
}
