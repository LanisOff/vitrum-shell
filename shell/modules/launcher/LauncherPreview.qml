import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components
import "../../lib/spotlight.js" as Spot

/*
 * Spotlight's preview: what the selected result is, larger. By kind —
 *   app      the icon, the name, what it is, the command
 *   game     the cover, when it was last played
 *   window   the app's icon, the title, the workspace
 *   file     a picture, or the first lines of a text file, and the path
 *   clip     the copied text in full, or the picture
 *   emoji    the glyph, large, its name and code points
 *   calc     the result, large, and the sum
 *   web / action / command / ssh / timer   an icon and what Enter does
 * The contents cross-fade when the selection moves.
 */
Item {
    id: root
    property var item: null
    readonly property string kind: item ? (item.kind || "action") : ""

    // A new selection: fade the old out and the new in.
    property var shown: null
    onItemChanged: { if (!Motion.enabled) { shown = item; return; } swap.restart(); }
    Component.onCompleted: shown = item
    SequentialAnimation {
        id: swap
        NumberAnimation { target: body; property: "opacity"; to: 0; duration: 70 }
        ScriptAction { script: root.shown = root.item }
        NumberAnimation { target: body; property: "opacity"; to: 1; duration: Motion.fast; easing.type: Easing.OutCubic }
    }
    readonly property string k: shown ? (shown.kind || "action") : ""

    // A text file's first lines.
    property string fileText: ""
    Process {
        id: head
        stdout: StdioCollector { onStreamFinished: root.fileText = text }
    }
    onShownChanged: {
        fileText = "";
        if (shown && shown.kind === "clip") Clipboard.requestPreview(shown.entry);
        if (shown && shown.kind === "file" && Spot.fileKind(shown.path) === "text") {
            head.command = ["head", "-c", "1800", shown.path];
            head.running = true;
        }
    }
    // Copied text, whole once decoded (the list's preview until then).
    readonly property string clipText: shown && shown.kind === "clip" && shown.entry
        ? (Clipboard.fullId === shown.entry.id && Clipboard.fullText ? Clipboard.fullText : shown.entry.preview) : ""
    readonly property string clipImage: shown && shown.kind === "clip" && shown.entry && shown.entry.isImage ? Clipboard.imagePath(shown.entry) : ""

    Column {
        id: body
        anchors.fill: parent
        anchors.margins: Tokens.padding
        spacing: Tokens.gap
        visible: root.shown !== null

        // ------------------------------------------------------- the hero ---
        Item {
            id: hero
            width: parent.width
            height: root.k === "clip" || root.k === "file" ? Math.min(parent.height * 0.62, width * 0.75)
                  : root.k === "game" ? Math.min(parent.height * 0.7, width * 0.9)
                  : Tokens.iconSize * 5
            // Big icon: apps, windows, actions.
            IconImage {
                anchors.centerIn: parent
                width: Tokens.iconSize * 4; height: width
                visible: !!(root.shown && root.shown.app) && (root.k === "app" || root.k === "window")
                source: root.shown && root.shown.app ? Quickshell.iconPath(root.shown.app.icon, "application-x-executable") : ""
            }
            Icon {
                anchors.centerIn: parent
                visible: ["action", "web", "command", "ssh", "timer", "pane"].indexOf(root.k) >= 0 || (root.k === "window" && !(root.shown && root.shown.app))
                       || (root.k === "file" && Spot.fileKind(root.shown ? root.shown.path : "") === "other")
                name: root.shown ? (root.shown.icon || "help") : "help"
                size: Tokens.iconSize * 3.4
                color: Colors.accent
            }
            // Emoji and symbols, large.
            Text {
                anchors.centerIn: parent
                visible: root.k === "emoji"
                text: root.shown && root.shown.glyph ? root.shown.glyph : ""
                font.pixelSize: Tokens.iconSize * 4.6
                color: Colors.text
            }
            // A sum's result, large.
            Label {
                anchors.centerIn: parent
                width: parent.width
                visible: root.k === "calc"
                text: root.shown ? root.shown.title : ""
                horizontalAlignment: Text.AlignHCenter
                size: Tokens.textTitle * 1.6
                font.weight: Font.DemiBold
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: Tokens.textLarge
                numeric: true
            }
            // Pictures: a game's cover, an image file, a copied picture.
            Rectangle {
                anchors.centerIn: parent
                visible: pic.visible
                width: pic.paintedWidth + 2; height: pic.paintedHeight + 2
                radius: Tokens.radiusInner
                color: "transparent"
                border.width: Tokens.hairline
                border.color: Colors.alpha(Colors.text, 0.12)
            }
            Image {
                id: pic
                anchors.fill: parent
                visible: status === Image.Ready && (root.k === "game" || root.k === "file" || root.k === "clip")
                source: root.k === "game" && root.shown.game && root.shown.game.cover ? "file://" + root.shown.game.cover
                      : root.k === "file" && Spot.fileKind(root.shown.path) === "image" ? "file://" + root.shown.path
                      : root.k === "clip" && root.clipImage ? "file://" + root.clipImage : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                sourceSize.width: 640
            }
            // A text file or copied text: the words themselves.
            Rectangle {
                anchors.fill: parent
                visible: (root.k === "file" && root.fileText.length > 0) || (root.k === "clip" && root.shown.entry && !root.shown.entry.isImage)
                radius: Tokens.radiusInner
                color: Colors.alpha(Colors.text, 0.05)
                clip: true
                Text {
                    anchors.fill: parent
                    anchors.margins: Tokens.gap
                    text: root.k === "file" ? root.fileText : root.clipText
                    color: Colors.text
                    font.family: root.k === "file" ? "monospace" : Tokens.fontText
                    font.pixelSize: root.k === "file" ? Tokens.textSmall : Tokens.textSize
                    wrapMode: Text.WrapAnywhere
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
            }
        }

        // ------------------------------------------------------ the words ---
        Label {
            width: parent.width
            visible: root.k !== "calc"
            text: root.shown ? (root.k === "emoji" ? root.shown.title : root.shown.title) : ""
            size: Tokens.textLarge
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        Label {
            width: parent.width
            visible: text.length > 0
            text: root.detail
            role: "dim"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }
        Label {
            width: parent.width
            visible: text.length > 0
            text: root.hint
            role: "dim"
            size: Tokens.textSmall
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }

    readonly property string detail: {
        const s = shown;
        if (!s) return "";
        switch (k) {
        case "app": return s.app ? (s.app.comment || s.app.genericName || "") : "";
        case "game": return s.game && s.game.lastPlayed ? "Last played " + Qt.formatDate(new Date(s.game.lastPlayed * 1000), "d MMMM yyyy") : "Not played yet";
        case "window": return s.subtitle || "";
        case "file": return s.subtitle || "";
        case "clip": return s.entry && s.entry.isImage ? s.entry.preview.replace(/^\[\[ binary data |\]\]$/g, "") : (root.clipText.length + (root.clipText.length >= 20000 ? "+" : "") + " characters");
        case "emoji": return Spot.codePoints(s.glyph) + (s.group ? " · " + s.group : "");
        case "calc": return s.subtitle || "";
        default: return s.subtitle || "";
        }
    }
    readonly property string hint: {
        switch (k) {
        case "app": return "Enter opens it";
        case "game": return "Enter plays it in Steam";
        case "window": return "Enter switches to it";
        case "file": return "Enter opens it · Ctrl+Enter shows it in its folder";
        case "clip": return "Enter copies it · Delete removes it";
        case "emoji": return "Enter copies it";
        case "calc": return "Enter copies the result";
        case "web": return "Enter searches in your browser";
        case "pane": return "Enter opens Settings there";
        default: return "";
        }
    }
}
