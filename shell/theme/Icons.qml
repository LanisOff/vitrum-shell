pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "../lib/icons.js" as IconsLib

/*
 * UI icons by name (shell/data/icons.json): Material Symbols Rounded, or Nerd
 * Font glyphs in the mono font preset, falling back to Material Symbols.
 */
Singleton {
    id: root
    property var map: ({})
    readonly property string preset: Settings.get("fonts.preset", "sans")

    function glyph(name) { return IconsLib.glyph(map, name, preset); }

    FileView {
        path: Qt.resolvedUrl("../data/icons.json").toString().replace("file://", "")
        onLoaded: root.map = JSON.parse(text())
    }
}
