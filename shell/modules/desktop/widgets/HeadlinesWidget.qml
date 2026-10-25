import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import "../../../lib/rss.js" as Lib

/*
 * The latest headlines from a few RSS or Atom feeds (curl, every half hour;
 * read by lib/rss.js), newest first. A click opens the story.
 *   M   the header; two or three headlines, one line each, the source and
 *       how long ago under it
 *   L   as M, each headline on up to two lines, as many as fit
 * options: feeds (the URLs, ten at most), source (the feed's name beside the age).
 * Not fetched under a game; when it ends, asked again only if half an hour
 * has passed. In a gallery card, sample headlines; nothing is fetched.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    // preview is set after Component.onCompleted: start a turn later, once it is known.
    property bool started: false
    Component.onCompleted: Qt.callLater(() => root.started = true)
    readonly property bool live: started && !preview
    readonly property bool awake: live && !GameMode.active

    readonly property var urls: Lib.urls(options.feeds || [])
    readonly property string urlsKey: urls.join(" ")
    readonly property bool showSource: options.source !== false
    readonly property bool tall: sizeClass === "L" || sizeClass === "XL"
    readonly property int every: 30 * 60 * 1000

    property var items: []
    property bool loading: false
    property bool fetchedOnce: false
    property string error: ""
    property string fetchedKey: ""
    property real fetchedAt: 0
    property real now: Date.now()

    readonly property real sampleNow: Date.UTC(2026, 0, 1, 12)
    readonly property var sample: [
        { title: "A 1,000-mile cloud on Mars may reveal physics never seen in nature", source: "Ars Technica", time: sampleNow - 14 * 60000 },
        { title: "The open-source desktop had its best year yet", source: "The Verge", time: sampleNow - 52 * 60000 },
        { title: "Rust 2.0 is out, and the borrow checker learned to explain itself", source: "Ars Technica", time: sampleNow - 3 * 3600000 },
        { title: "Why every phone is a slab now, and what comes after", source: "The Verge", time: sampleNow - 7 * 3600000 },
        { title: "A tiny satellite maps methane leaks from orbit", source: "Ars Technica", time: sampleNow - 26 * 3600000 }
    ]
    readonly property var shown: preview ? sample : items
    readonly property real clock: preview ? sampleNow : now

    // ------------------------------------------------------- fetching ---
    function refresh() {
        if (!live || !urls.length) return;
        if (fetch.running) { _again = true; return; }
        fetchedKey = urlsKey;
        fetchedAt = Date.now();
        loading = true;
        // Each feed after a line of SEP + its URL; a feed that fails is empty.
        fetch.command = ["sh", "-c", 'for u; do printf "\\036%s\\n" "$u"; curl -fsSL --compressed --connect-timeout 4 --max-time 12 -A vitrum-headlines "$u" 2>/dev/null | head -c 3000000; echo; done', "_"].concat(urls);
        fetch.running = true;
    }
    property bool _again: false
    Process {
        id: fetch
        stdout: StdioCollector {
            onStreamFinished: {
                const feeds = Lib.splitFeeds(text).map(f => Lib.parseFeed(f.body, f.url));
                const merged = Lib.merge(feeds, 40);
                root.fetchedOnce = true;
                // A round where every feed failed keeps the headlines there were.
                if (merged.length || !root.items.length) root.items = merged;
                root.error = merged.length ? "" : feeds.length === 1 && feeds[0].error !== "Empty reply" ? feeds[0].error : "Could not load the feeds";
                root.now = Date.now();
            }
        }
        onExited: {
            root.loading = false;
            if (root._again) { root._again = false; root.refresh(); }
        }
    }
    Timer {
        interval: root.every
        repeat: true
        running: root.awake && root.urls.length > 0
        triggeredOnStart: true
        onTriggered: if (root.fetchedKey !== root.urlsKey || Date.now() - root.fetchedAt >= root.every - 60000 || !root.fetchedOnce) root.refresh()
    }
    // Other feeds: asked once the list settles (typing in the options).
    onUrlsKeyChanged: if (awake) settle.restart()
    Timer { id: settle; interval: 1500; onTriggered: if (root.fetchedKey !== root.urlsKey) { root.items = []; root.refresh(); } }
    // The ages move on once a minute while it shows.
    Timer { interval: 60000; repeat: true; running: root.awake && root.items.length > 0; onTriggered: root.now = Date.now() }

    function open(link) { if (link && !root.preview) Quickshell.execDetached(["xdg-open", link]); }

    // -------------------------------------------------------- drawing ---
    WidgetHeader {
        id: head
        icon: "news"; title: "Headlines"
        trailing: root.loading && root.shown.length ? "Updating…" : ""
    }
    WidgetEmpty {
        visible: root.shown.length === 0
        anchors.verticalCenterOffset: head.height / 2
        icon: "news"
        text: !root.urls.length ? "Add feeds in the widget's options"
            : root.error ? root.error : "Loading…"
    }

    Column {
        id: list
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: Tokens.gap * 0.4; bottom: parent.bottom }
        spacing: Math.round(Tokens.gap * 0.3)
        readonly property int lines: root.tall ? 2 : 1
        readonly property real lineH: Math.ceil(Tokens.textSize * 1.3)
        readonly property real rowH: lines * lineH + Math.ceil(Tokens.textSmall * 1.35) + Math.round(Tokens.gap * 0.5)
        readonly property int fits: Math.max(0, Math.floor((height + spacing) / (rowH + spacing)))
        Repeater {
            model: root.shown.slice(0, list.fits)
            delegate: Item {
                id: row
                required property var modelData
                width: list.width; height: list.rowH
                // A faint lift under the pointer: it opens.
                Rectangle {
                    anchors { fill: parent; leftMargin: -Tokens.gap * 0.4; rightMargin: -Tokens.gap * 0.4 }
                    radius: Tokens.radiusButton
                    color: Colors.alpha(Colors.text, tap.pressed ? 0.10 : tap.containsMouse ? 0.06 : 0)
                    Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
                }
                Column {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                    Label {
                        width: parent.width
                        text: row.modelData.title
                        size: Tokens.textSize; font.weight: Font.Medium
                        wrapMode: Text.WordWrap
                        maximumLineCount: list.lines
                        lineHeightMode: Text.FixedHeight
                        lineHeight: list.lineH
                    }
                    Label {
                        width: parent.width
                        text: [root.showSource ? row.modelData.source : "", Lib.age(row.modelData.time, root.clock)].filter(s => s).join(" · ")
                        role: "dim"; size: Tokens.textSmall
                    }
                }
                MouseArea {
                    id: tap
                    anchors.fill: parent
                    enabled: !root.preview && !!row.modelData.link
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.open(row.modelData.link)
                }
            }
        }
    }
}
