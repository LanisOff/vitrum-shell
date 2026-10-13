import QtQuick
import qs.services
import qs.theme
import qs.components

/*
 * A line worth keeping, from the classics (all public domain).
 *   M   the quote mark in the accent, the words beside it, the author under them
 *   L   the same, the mark above, the words larger
 * options: every (day, hour, or click). A click always brings the next one.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    readonly property var quotes: [
        { a: "Seneca", t: "While we wait for life, life passes." },
        { a: "Seneca", t: "We suffer more often in imagination than in reality." },
        { a: "Seneca", t: "It is not that we have a short time to live, but that we waste a lot of it." },
        { a: "Seneca", t: "Begin at once to live." },
        { a: "Marcus Aurelius", t: "The happiness of your life depends upon the quality of your thoughts." },
        { a: "Marcus Aurelius", t: "Waste no more time arguing what a good man should be. Be one." },
        { a: "Marcus Aurelius", t: "Very little is needed to make a happy life." },
        { a: "Marcus Aurelius", t: "The best revenge is not to be like your enemy." },
        { a: "Lao Tzu", t: "A journey of a thousand miles begins with a single step." },
        { a: "Lao Tzu", t: "Nature does not hurry, yet everything is accomplished." },
        { a: "Lao Tzu", t: "Knowing others is wisdom; knowing yourself is enlightenment." },
        { a: "Henry David Thoreau", t: "Our life is frittered away by detail. Simplify, simplify." },
        { a: "Henry David Thoreau", t: "Not until we are lost do we begin to understand ourselves." },
        { a: "Henry David Thoreau", t: "Heaven is under our feet as well as over our heads." },
        { a: "Mark Twain", t: "Whenever you find yourself on the side of the majority, it is time to pause and reflect." },
        { a: "Mark Twain", t: "The secret of getting ahead is getting started." },
        { a: "Oscar Wilde", t: "We are all in the gutter, but some of us are looking at the stars." },
        { a: "Oscar Wilde", t: "To live is the rarest thing in the world. Most people exist, that is all." },
        { a: "Oscar Wilde", t: "Experience is simply the name we give our mistakes." },
        { a: "Albert Einstein", t: "Imagination is more important than knowledge." },
        { a: "Albert Einstein", t: "Life is like riding a bicycle. To keep your balance you must keep moving." },
        { a: "Albert Einstein", t: "The important thing is not to stop questioning." },
        { a: "Confucius", t: "It does not matter how slowly you go as long as you do not stop." },
        { a: "Confucius", t: "Real knowledge is to know the extent of one's ignorance." },
        { a: "Aristotle", t: "Well begun is half done." },
        { a: "Heraclitus", t: "No man ever steps in the same river twice." },
        { a: "Epictetus", t: "First say to yourself what you would be; and then do what you have to do." },
        { a: "Epictetus", t: "Wealth consists not in having great possessions, but in having few wants." },
        { a: "Ralph Waldo Emerson", t: "Adopt the pace of nature: her secret is patience." },
        { a: "Ralph Waldo Emerson", t: "The earth laughs in flowers." },
        { a: "Ralph Waldo Emerson", t: "Write it on your heart that every day is the best day in the year." },
        { a: "Benjamin Franklin", t: "Well done is better than well said." },
        { a: "Benjamin Franklin", t: "Lost time is never found again." },
        { a: "William Shakespeare", t: "We know what we are, but know not what we may be." },
        { a: "Walt Whitman", t: "Keep your face always toward the sunshine, and shadows will fall behind you." },
        { a: "Voltaire", t: "The best is the enemy of the good." },
        { a: "Plato", t: "The beginning is the most important part of the work." },
        { a: "Socrates", t: "The unexamined life is not worth living." },
        { a: "Leo Tolstoy", t: "The two most powerful warriors are patience and time." },
        { a: "Michel de Montaigne", t: "The greatest thing in the world is to know how to belong to oneself." },
        { a: "Matsuo Bashō", t: "Do not seek to follow in the footsteps of the wise; seek what they sought." },
        { a: "Blaise Pascal", t: "All of humanity's problems stem from man's inability to sit quietly in a room alone." }
    ]

    readonly property string every: options.every === "hour" || options.every === "click" ? options.every : "day"

    // Day and hour picks follow the clock (checked each minute); "click" starts
    // somewhere random. Clicks step on from wherever it is.
    property date now: new Date()
    Timer { interval: 60 * 1000; repeat: true; running: root.every !== "click" && !root.preview; onTriggered: root.now = new Date() }
    readonly property int seed: Math.floor(Math.random() * 1000)
    readonly property int base: {
        const d = now;
        const day = Math.floor((d - new Date(d.getFullYear(), 0, 0)) / 86400000);
        return every === "click" ? seed : every === "hour" ? day * 24 + d.getHours() : day;
    }
    property int step: 0
    onBaseChanged: step = 0
    readonly property int pick: (base + step) % quotes.length

    // What is on show; changes go through a fade.
    property int shown: 0
    Component.onCompleted: shown = pick
    onPickChanged: {
        if (!Motion.enabled) { shown = pick; return; }
        swap.restart();
    }
    SequentialAnimation {
        id: swap
        NumberAnimation { target: body; property: "opacity"; to: 0; duration: Motion.standard; easing.type: Easing.InCubic }
        ScriptAction { script: root.shown = root.pick }
        NumberAnimation { target: body; property: "opacity"; to: 1; duration: Motion.emphasized; easing.type: Easing.OutCubic }
    }

    readonly property var quote: quotes[shown] || quotes[0]
    readonly property bool large: sizeClass === "L" || sizeClass === "XL" || height > 220

    Item {
        id: body
        anchors.fill: parent

        Icon {
            id: mark
            name: "quote"
            filled: true
            color: Colors.accent
            size: root.large ? Math.round(Tokens.textTitle * 1.9) : Math.round(Tokens.textTitle * 1.5)
            anchors { left: parent.left; top: parent.top; leftMargin: -Math.round(mark.size * 0.12) }
        }
        Label {
            id: words
            anchors {
                left: root.large ? parent.left : mark.right
                leftMargin: root.large ? 0 : Tokens.gap * 0.6
                right: parent.right
                top: root.large ? mark.bottom : parent.top
                topMargin: root.large ? Tokens.gap * 0.4 : Math.round(mark.size * 0.12)
                bottom: author.top
                bottomMargin: Tokens.gap * 0.5
            }
            text: root.quote.t
            size: root.large ? Tokens.textTitle : Tokens.textLarge
            font.weight: Font.Light
            lineHeight: 1.15
            wrapMode: Text.WordWrap
            // Long lines step down rather than run off the plate.
            fontSizeMode: Text.Fit
            minimumPixelSize: Tokens.textSmall
            verticalAlignment: root.large ? Text.AlignVCenter : Text.AlignTop
            elide: Text.ElideRight
        }
        Label {
            id: author
            anchors { right: parent.right; bottom: parent.bottom; left: parent.left }
            horizontalAlignment: Text.AlignRight
            text: "— " + root.quote.a
            role: "dim"
            size: Tokens.textSmall + (root.large ? 1 : 0)
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.preview
        cursorShape: Qt.PointingHandCursor
        onClicked: root.step++
    }
}
