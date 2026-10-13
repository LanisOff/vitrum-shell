import QtQuick
import Quickshell.Io
import qs.theme
import qs.components

// An example of a widget of your own: how long the machine has been up.
// Copy this folder, rename it, edit; the editor's Custom tab lists it, and
// saving this file reloads it on the desktop. The four properties below are
// what every widget gets; options come from manifest.json, defaults filled in.
Item {
    id: root
    property var options: ({})
    property string sizeClass: "S"          // S, M, L or XL: lay out for it
    property bool preview: false            // true in the gallery: keep it cheap
    signal optionsEdited(var options)       // for content you keep in options

    property real up: 0
    FileView { id: f; path: "/proc/uptime"; onLoaded: root.up = parseFloat(text().split(" ")[0]) || 0 }
    Timer { interval: root.options.seconds ? 1000 : 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: f.reload() }

    readonly property string text: {
        const s = Math.floor(up), d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return (d ? d + "d " : "") + h + "h " + m + "m" + (root.options.seconds ? " " + s % 60 + "s" : "");
    }
    WidgetHeader { id: head; visible: root.sizeClass !== "S"; icon: "clock"; title: "Uptime" }
    Metric {
        // Centred when small; under the header, at the bottom, otherwise.
        x: root.sizeClass === "S" ? (root.width - width) / 2 : 0
        y: root.sizeClass === "S" ? (root.height - height) / 2 : root.height - height
        value: root.text
        label: root.options.label || ""
        size: root.sizeClass === "S" ? 26 : 34
    }
}
