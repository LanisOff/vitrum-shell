import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components

/*
 * The Steam games played last, as their covers (vitrum-steam, the launcher's
 * Games tab's source), read on load and every ten minutes.
 *   M      the header, then `count` covers in a row, as wide as the plate allows
 *   L/XL   the same, bigger, each with its name and when it was last played under it
 * options: count. A click on a cover starts the game.
 * In a gallery card tinted placeholders with names stand in; nothing is run.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    property var games: []
    property bool loaded: false

    Process {
        id: steamProc
        command: ["vitrum-steam"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try { list = JSON.parse(text); } catch (e) { list = []; }
                if (!Array.isArray(list)) list = [];
                list.sort((a, b) => (b.lastPlayed || 0) - (a.lastPlayed || 0));
                root.games = list;
                root.loaded = true;
            }
        }
        onExited: (code, status) => { if (code !== 0) root.loaded = true; }
    }
    // Deferred: the host sets preview just after this item is made.
    function reload() { Qt.callLater(_reload); }
    function _reload() { if (!preview && !steamProc.running) steamProc.running = true; }
    Component.onCompleted: reload()
    Timer { interval: 10 * 60 * 1000; repeat: true; running: !root.preview; onTriggered: root.reload() }

    readonly property var sample: ["Hades", "Celeste", "Portal 2", "Stardew Valley", "Hollow Knight", "Outer Wilds", "Disco Elysium", "Factorio"]
        .map((n, i) => ({ appid: 0, name: n, lastPlayed: 0, cover: "", hue: i * 45 }))
    readonly property int count: Math.max(2, Math.min(8, Number(options.count) || 4))
    readonly property var shown: (preview ? sample : games).slice(0, count)
    readonly property bool named: sizeClass !== "M" && sizeClass !== "S"

    function play(g) { if (!preview && g.appid) Apps.runProc(["steam", "steam://rungameid/" + g.appid]); }
    function ago(sec) {
        if (!sec) return "Not played yet";
        const d = (Date.now() / 1000 - sec) / 86400;
        if (d < 1) return "Today";
        if (d < 2) return "Yesterday";
        if (d < 30) return Math.floor(d) + " days ago";
        if (d < 365) return Math.floor(d / 30) + (d < 60 ? " month ago" : " months ago");
        return Qt.formatDate(new Date(sec * 1000), "MMM yyyy");
    }

    WidgetHeader {
        id: head
        icon: "gamepad"
        title: "Steam"
        trailing: root.preview ? "" : root.games.length ? root.games.length + (root.games.length === 1 ? " game" : " games") : ""
    }
    WidgetEmpty {
        visible: !root.preview && root.loaded && root.games.length === 0
        icon: "gamepad"
        text: "No Steam games found"
    }

    // ---- the covers: 2:3, as big as both the width and the height allow.
    Item {
        id: shelf
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: Tokens.gap * 0.7; bottom: parent.bottom }
        readonly property real gap: Tokens.gap
        readonly property real textH: root.named ? Math.round(Tokens.textSmall * 1.5 + Tokens.textSmall * 1.4 + Tokens.gap * 0.4) : 0
        readonly property real coverW: Math.max(8, Math.min((width - (root.count - 1) * gap) / root.count, (height - textH) / 1.5))
        readonly property real coverH: coverW * 1.5

        Row {
            id: row
            anchors.centerIn: parent
            spacing: shelf.gap
            Repeater {
                model: root.shown
                delegate: Item {
                    id: game
                    required property var modelData
                    required property int index
                    width: shelf.coverW
                    height: shelf.coverH + shelf.textH
                    readonly property bool hasCover: !!modelData.cover && art.status === Image.Ready

                    Item {
                        id: plate
                        width: parent.width; height: shelf.coverH
                        scale: gm.pressed ? 0.95 : gm.containsMouse ? 1.04 : 1
                        Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }

                        // Under the cover while it loads, or instead of one.
                        Rectangle {
                            id: ph
                            anchors.fill: parent
                            radius: Tokens.radiusInner
                            visible: !game.hasCover
                            readonly property color tone: root.preview ? Colors.ink(game.modelData.hue || 0) : Colors.alpha(Colors.text, 0.5)
                            gradient: Gradient {
                                GradientStop { position: 0; color: Colors.alpha(ph.tone, root.preview ? 0.55 : 0.12) }
                                GradientStop { position: 1; color: Colors.alpha(ph.tone, root.preview ? 0.25 : 0.06) }
                            }
                            border.width: Tokens.hairline
                            border.color: Colors.alpha(Colors.text, 0.08)
                            Label {
                                visible: !root.named
                                anchors.centerIn: parent
                                width: parent.width - Tokens.gap
                                text: game.modelData.name
                                size: Tokens.textSmall
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                            }
                            Icon {
                                visible: root.named
                                anchors.centerIn: parent
                                name: "gamepad"
                                size: Math.round(Math.min(parent.width * 0.4, Tokens.iconSize * 2.4))
                                color: root.preview ? Colors.text : Colors.textDim
                                opacity: 0.8
                            }
                        }
                        RoundImage {
                            id: art
                            anchors.fill: parent
                            radius: Tokens.radiusInner
                            source: game.modelData.cover ? "file://" + game.modelData.cover : ""
                            sourceWidth: 300
                        }
                        MouseArea {
                            id: gm
                            anchors.fill: parent
                            enabled: !root.preview
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.play(game.modelData)
                        }
                    }
                    Column {
                        visible: root.named
                        anchors { top: plate.bottom; topMargin: Tokens.gap * 0.4; left: parent.left; right: parent.right }
                        Label { width: parent.width; text: game.modelData.name; size: Tokens.textSmall; font.weight: Font.Medium }
                        Label { width: parent.width; text: root.preview ? ["Today", "Yesterday", "3 days ago", "2 weeks ago"][game.index % 4] : root.ago(game.modelData.lastPlayed)
                                role: "dim"; size: Tokens.textSmall - 1 }
                    }
                }
            }
        }
    }
}
