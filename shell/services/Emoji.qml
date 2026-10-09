pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * The emoji picker's catalogue.
 *
 * Shipped inline rather than parsed from a Unicode data file: the picker has
 * to answer on the first keystroke, and loading and indexing 4,000 entries at
 * startup to serve a list people scroll through is the wrong trade. This is
 * the set that actually gets used, with the keywords people actually type.
 *
 * They render in the Apple emoji font the installer fetched, which is the
 * point of the whole exercise.
 */
Singleton {
    id: root

    readonly property var categories: [
        "Frequent", "Smileys", "People", "Nature", "Food",
        "Activity", "Travel", "Objects", "Symbols", "Flags"
    ]

    readonly property var all: [
        // ---- Smileys -----------------------------------------------------
        { char: "😀", name: "grinning face", keywords: "smile happy grin", cat: "Smileys" },
        { char: "😃", name: "grinning face with big eyes", keywords: "smile happy joy", cat: "Smileys" },
        { char: "😄", name: "grinning face with smiling eyes", keywords: "smile happy laugh", cat: "Smileys" },
        { char: "😁", name: "beaming face", keywords: "smile grin teeth", cat: "Smileys" },
        { char: "😆", name: "grinning squinting face", keywords: "laugh haha lol", cat: "Smileys" },
        { char: "😅", name: "grinning face with sweat", keywords: "relief phew laugh", cat: "Smileys" },
        { char: "🤣", name: "rolling on the floor laughing", keywords: "rofl lol funny", cat: "Smileys" },
        { char: "😂", name: "face with tears of joy", keywords: "lol cry laugh funny", cat: "Smileys" },
        { char: "🙂", name: "slightly smiling face", keywords: "smile ok fine", cat: "Smileys" },
        { char: "🙃", name: "upside-down face", keywords: "sarcasm irony silly", cat: "Smileys" },
        { char: "😉", name: "winking face", keywords: "wink flirt", cat: "Smileys" },
        { char: "😊", name: "smiling face with smiling eyes", keywords: "blush happy warm", cat: "Smileys" },
        { char: "😇", name: "smiling face with halo", keywords: "angel innocent", cat: "Smileys" },
        { char: "🥰", name: "smiling face with hearts", keywords: "love adore crush", cat: "Smileys" },
        { char: "😍", name: "smiling face with heart-eyes", keywords: "love crush amazing", cat: "Smileys" },
        { char: "😘", name: "face blowing a kiss", keywords: "kiss love", cat: "Smileys" },
        { char: "😋", name: "face savoring food", keywords: "yum tasty delicious", cat: "Smileys" },
        { char: "😜", name: "winking face with tongue", keywords: "silly joke crazy", cat: "Smileys" },
        { char: "🤪", name: "zany face", keywords: "crazy wild goofy", cat: "Smileys" },
        { char: "🤨", name: "face with raised eyebrow", keywords: "skeptic suspicious doubt", cat: "Smileys" },
        { char: "🧐", name: "face with monocle", keywords: "inspect examine posh", cat: "Smileys" },
        { char: "🤓", name: "nerd face", keywords: "geek smart glasses", cat: "Smileys" },
        { char: "😎", name: "smiling face with sunglasses", keywords: "cool sunglasses", cat: "Smileys" },
        { char: "🥳", name: "partying face", keywords: "party celebrate birthday", cat: "Smileys" },
        { char: "😏", name: "smirking face", keywords: "smug sly", cat: "Smileys" },
        { char: "😒", name: "unamused face", keywords: "meh unimpressed", cat: "Smileys" },
        { char: "😞", name: "disappointed face", keywords: "sad let down", cat: "Smileys" },
        { char: "😔", name: "pensive face", keywords: "sad quiet", cat: "Smileys" },
        { char: "😟", name: "worried face", keywords: "concern anxious", cat: "Smileys" },
        { char: "😕", name: "confused face", keywords: "unsure puzzled", cat: "Smileys" },
        { char: "🙁", name: "slightly frowning face", keywords: "sad frown", cat: "Smileys" },
        { char: "😣", name: "persevering face", keywords: "struggle tough", cat: "Smileys" },
        { char: "😖", name: "confounded face", keywords: "frustrated argh", cat: "Smileys" },
        { char: "😫", name: "tired face", keywords: "exhausted done", cat: "Smileys" },
        { char: "😩", name: "weary face", keywords: "tired ugh", cat: "Smileys" },
        { char: "🥺", name: "pleading face", keywords: "puppy eyes please beg", cat: "Smileys" },
        { char: "😢", name: "crying face", keywords: "sad tear cry", cat: "Smileys" },
        { char: "😭", name: "loudly crying face", keywords: "sob cry sad", cat: "Smileys" },
        { char: "😤", name: "face with steam from nose", keywords: "triumph determined", cat: "Smileys" },
        { char: "😠", name: "angry face", keywords: "mad annoyed", cat: "Smileys" },
        { char: "😡", name: "enraged face", keywords: "rage furious mad", cat: "Smileys" },
        { char: "🤯", name: "exploding head", keywords: "mind blown shocked", cat: "Smileys" },
        { char: "😳", name: "flushed face", keywords: "embarrassed shy", cat: "Smileys" },
        { char: "🥵", name: "hot face", keywords: "heat sweating", cat: "Smileys" },
        { char: "🥶", name: "cold face", keywords: "freezing ice", cat: "Smileys" },
        { char: "😱", name: "face screaming in fear", keywords: "scared shock horror", cat: "Smileys" },
        { char: "😨", name: "fearful face", keywords: "scared afraid", cat: "Smileys" },
        { char: "😰", name: "anxious face with sweat", keywords: "nervous worried", cat: "Smileys" },
        { char: "🤗", name: "hugging face", keywords: "hug welcome", cat: "Smileys" },
        { char: "🤔", name: "thinking face", keywords: "hmm consider think", cat: "Smileys" },
        { char: "🤫", name: "shushing face", keywords: "quiet secret shh", cat: "Smileys" },
        { char: "🙄", name: "face with rolling eyes", keywords: "eyeroll whatever", cat: "Smileys" },
        { char: "😴", name: "sleeping face", keywords: "sleep zzz tired", cat: "Smileys" },
        { char: "🤒", name: "face with thermometer", keywords: "sick ill fever", cat: "Smileys" },
        { char: "🤮", name: "face vomiting", keywords: "sick gross puke", cat: "Smileys" },
        { char: "😷", name: "face with medical mask", keywords: "sick mask", cat: "Smileys" },
        { char: "💀", name: "skull", keywords: "dead death dying", cat: "Smileys" },
        { char: "👻", name: "ghost", keywords: "spooky halloween boo", cat: "Smileys" },
        { char: "👽", name: "alien", keywords: "ufo space", cat: "Smileys" },
        { char: "🤖", name: "robot", keywords: "bot ai machine", cat: "Smileys" },
        { char: "💩", name: "pile of poo", keywords: "poop crap", cat: "Smileys" },
        { char: "🤡", name: "clown face", keywords: "joker circus", cat: "Smileys" },

        // ---- People / gestures --------------------------------------------
        { char: "👍", name: "thumbs up", keywords: "yes approve like good", cat: "People" },
        { char: "👎", name: "thumbs down", keywords: "no disapprove bad", cat: "People" },
        { char: "👌", name: "ok hand", keywords: "perfect fine ok", cat: "People" },
        { char: "🤌", name: "pinched fingers", keywords: "italian gesture", cat: "People" },
        { char: "✌️", name: "victory hand", keywords: "peace two", cat: "People" },
        { char: "🤞", name: "crossed fingers", keywords: "luck hope", cat: "People" },
        { char: "🤟", name: "love-you gesture", keywords: "ily love", cat: "People" },
        { char: "🤙", name: "call me hand", keywords: "shaka hang loose", cat: "People" },
        { char: "👋", name: "waving hand", keywords: "hello hi bye wave", cat: "People" },
        { char: "🙏", name: "folded hands", keywords: "please thanks pray", cat: "People" },
        { char: "👏", name: "clapping hands", keywords: "applause bravo clap", cat: "People" },
        { char: "🙌", name: "raising hands", keywords: "celebrate hooray praise", cat: "People" },
        { char: "💪", name: "flexed biceps", keywords: "strong muscle gym", cat: "People" },
        { char: "🫡", name: "saluting face", keywords: "salute respect yes sir", cat: "People" },
        { char: "🤝", name: "handshake", keywords: "deal agreement", cat: "People" },
        { char: "✍️", name: "writing hand", keywords: "write note", cat: "People" },
        { char: "👀", name: "eyes", keywords: "look watch see", cat: "People" },
        { char: "🧠", name: "brain", keywords: "smart think mind", cat: "People" },
        { char: "🫀", name: "anatomical heart", keywords: "organ cardio", cat: "People" },
        { char: "👶", name: "baby", keywords: "child infant", cat: "People" },
        { char: "🧑‍💻", name: "technologist", keywords: "developer coder programmer", cat: "People" },
        { char: "👨‍💻", name: "man technologist", keywords: "developer coder", cat: "People" },
        { char: "👩‍💻", name: "woman technologist", keywords: "developer coder", cat: "People" },
        { char: "🕵️", name: "detective", keywords: "spy investigate", cat: "People" },
        { char: "🦸", name: "superhero", keywords: "hero super", cat: "People" },

        // ---- Nature --------------------------------------------------------
        { char: "🐶", name: "dog face", keywords: "puppy pet animal", cat: "Nature" },
        { char: "🐱", name: "cat face", keywords: "kitten pet animal", cat: "Nature" },
        { char: "🦊", name: "fox", keywords: "animal firefox", cat: "Nature" },
        { char: "🐻", name: "bear", keywords: "animal", cat: "Nature" },
        { char: "🐼", name: "panda", keywords: "animal bear", cat: "Nature" },
        { char: "🐧", name: "penguin", keywords: "linux animal bird", cat: "Nature" },
        { char: "🐦", name: "bird", keywords: "animal tweet", cat: "Nature" },
        { char: "🦆", name: "duck", keywords: "animal bird quack", cat: "Nature" },
        { char: "🐢", name: "turtle", keywords: "animal slow", cat: "Nature" },
        { char: "🐍", name: "snake", keywords: "python animal", cat: "Nature" },
        { char: "🦋", name: "butterfly", keywords: "insect pretty", cat: "Nature" },
        { char: "🐝", name: "honeybee", keywords: "insect bee", cat: "Nature" },
        { char: "🐛", name: "bug", keywords: "insect defect error", cat: "Nature" },
        { char: "🌸", name: "cherry blossom", keywords: "flower spring sakura", cat: "Nature" },
        { char: "🌹", name: "rose", keywords: "flower love", cat: "Nature" },
        { char: "🌻", name: "sunflower", keywords: "flower summer", cat: "Nature" },
        { char: "🌲", name: "evergreen tree", keywords: "tree forest pine", cat: "Nature" },
        { char: "🍀", name: "four leaf clover", keywords: "luck lucky", cat: "Nature" },
        { char: "🔥", name: "fire", keywords: "hot lit flame burn", cat: "Nature" },
        { char: "💧", name: "droplet", keywords: "water drop", cat: "Nature" },
        { char: "🌊", name: "water wave", keywords: "ocean sea surf", cat: "Nature" },
        { char: "⭐", name: "star", keywords: "favourite rating", cat: "Nature" },
        { char: "🌟", name: "glowing star", keywords: "sparkle shine", cat: "Nature" },
        { char: "⚡", name: "high voltage", keywords: "lightning fast power", cat: "Nature" },
        { char: "❄️", name: "snowflake", keywords: "cold winter snow", cat: "Nature" },
        { char: "🌈", name: "rainbow", keywords: "pride colour", cat: "Nature" },
        { char: "☀️", name: "sun", keywords: "sunny bright day", cat: "Nature" },
        { char: "🌙", name: "crescent moon", keywords: "night dark sleep", cat: "Nature" },

        // ---- Food ----------------------------------------------------------
        { char: "🍎", name: "red apple", keywords: "fruit apple mac", cat: "Food" },
        { char: "🍌", name: "banana", keywords: "fruit", cat: "Food" },
        { char: "🍕", name: "pizza", keywords: "food slice italian", cat: "Food" },
        { char: "🍔", name: "hamburger", keywords: "burger food", cat: "Food" },
        { char: "🍟", name: "french fries", keywords: "chips food", cat: "Food" },
        { char: "🌮", name: "taco", keywords: "food mexican", cat: "Food" },
        { char: "🍣", name: "sushi", keywords: "food japanese", cat: "Food" },
        { char: "🍰", name: "shortcake", keywords: "cake dessert sweet", cat: "Food" },
        { char: "🍪", name: "cookie", keywords: "biscuit sweet", cat: "Food" },
        { char: "☕", name: "hot beverage", keywords: "coffee tea morning", cat: "Food" },
        { char: "🍺", name: "beer mug", keywords: "drink pub alcohol", cat: "Food" },
        { char: "🍷", name: "wine glass", keywords: "drink alcohol", cat: "Food" },
        { char: "🥂", name: "clinking glasses", keywords: "celebrate cheers", cat: "Food" },

        // ---- Activity ------------------------------------------------------
        { char: "⚽", name: "soccer ball", keywords: "football sport", cat: "Activity" },
        { char: "🏀", name: "basketball", keywords: "sport", cat: "Activity" },
        { char: "🎮", name: "video game", keywords: "gaming controller play", cat: "Activity" },
        { char: "🎲", name: "game die", keywords: "dice random luck", cat: "Activity" },
        { char: "🎸", name: "guitar", keywords: "music rock", cat: "Activity" },
        { char: "🎧", name: "headphone", keywords: "music listen audio", cat: "Activity" },
        { char: "🎬", name: "clapper board", keywords: "film movie action", cat: "Activity" },
        { char: "🏆", name: "trophy", keywords: "win award first", cat: "Activity" },
        { char: "🎯", name: "bullseye", keywords: "target goal darts", cat: "Activity" },
        { char: "🎉", name: "party popper", keywords: "celebrate congrats party", cat: "Activity" },
        { char: "🎊", name: "confetti ball", keywords: "celebrate party", cat: "Activity" },
        { char: "🎁", name: "wrapped gift", keywords: "present birthday", cat: "Activity" },

        // ---- Travel --------------------------------------------------------
        { char: "🚀", name: "rocket", keywords: "launch ship fast deploy", cat: "Travel" },
        { char: "✈️", name: "airplane", keywords: "flight travel", cat: "Travel" },
        { char: "🚗", name: "automobile", keywords: "car drive", cat: "Travel" },
        { char: "🚲", name: "bicycle", keywords: "bike cycle", cat: "Travel" },
        { char: "🏠", name: "house", keywords: "home building", cat: "Travel" },
        { char: "🏢", name: "office building", keywords: "work office", cat: "Travel" },
        { char: "🗺️", name: "world map", keywords: "map travel geography", cat: "Travel" },
        { char: "🧭", name: "compass", keywords: "direction navigate", cat: "Travel" },

        // ---- Objects -------------------------------------------------------
        { char: "💻", name: "laptop", keywords: "computer macbook work", cat: "Objects" },
        { char: "🖥️", name: "desktop computer", keywords: "imac monitor pc", cat: "Objects" },
        { char: "⌨️", name: "keyboard", keywords: "type input", cat: "Objects" },
        { char: "🖱️", name: "computer mouse", keywords: "pointer click", cat: "Objects" },
        { char: "💾", name: "floppy disk", keywords: "save disk storage", cat: "Objects" },
        { char: "💿", name: "optical disk", keywords: "cd dvd disc", cat: "Objects" },
        { char: "📱", name: "mobile phone", keywords: "iphone smartphone", cat: "Objects" },
        { char: "📷", name: "camera", keywords: "photo picture", cat: "Objects" },
        { char: "🔋", name: "battery", keywords: "power charge", cat: "Objects" },
        { char: "🔌", name: "electric plug", keywords: "power charge socket", cat: "Objects" },
        { char: "💡", name: "light bulb", keywords: "idea bright", cat: "Objects" },
        { char: "🔦", name: "flashlight", keywords: "torch light", cat: "Objects" },
        { char: "🔑", name: "key", keywords: "password unlock access", cat: "Objects" },
        { char: "🔒", name: "locked", keywords: "secure private lock", cat: "Objects" },
        { char: "🔓", name: "unlocked", keywords: "open unlock", cat: "Objects" },
        { char: "🛠️", name: "hammer and wrench", keywords: "tools fix build", cat: "Objects" },
        { char: "⚙️", name: "gear", keywords: "settings config cog", cat: "Objects" },
        { char: "🧰", name: "toolbox", keywords: "tools repair", cat: "Objects" },
        { char: "📦", name: "package", keywords: "box parcel ship", cat: "Objects" },
        { char: "📝", name: "memo", keywords: "note write edit", cat: "Objects" },
        { char: "📅", name: "calendar", keywords: "date schedule", cat: "Objects" },
        { char: "📊", name: "bar chart", keywords: "graph stats data", cat: "Objects" },
        { char: "📈", name: "chart increasing", keywords: "growth up stats", cat: "Objects" },
        { char: "📉", name: "chart decreasing", keywords: "down loss stats", cat: "Objects" },
        { char: "🗑️", name: "wastebasket", keywords: "trash delete bin", cat: "Objects" },
        { char: "🧹", name: "broom", keywords: "clean sweep tidy", cat: "Objects" },

        // ---- Symbols -------------------------------------------------------
        { char: "❤️", name: "red heart", keywords: "love like", cat: "Symbols" },
        { char: "🧡", name: "orange heart", keywords: "love", cat: "Symbols" },
        { char: "💛", name: "yellow heart", keywords: "love", cat: "Symbols" },
        { char: "💚", name: "green heart", keywords: "love", cat: "Symbols" },
        { char: "💙", name: "blue heart", keywords: "love", cat: "Symbols" },
        { char: "💜", name: "purple heart", keywords: "love", cat: "Symbols" },
        { char: "🖤", name: "black heart", keywords: "love dark", cat: "Symbols" },
        { char: "💔", name: "broken heart", keywords: "sad breakup", cat: "Symbols" },
        { char: "✅", name: "check mark button", keywords: "done yes ok complete", cat: "Symbols" },
        { char: "❌", name: "cross mark", keywords: "no wrong error fail", cat: "Symbols" },
        { char: "⚠️", name: "warning", keywords: "caution alert danger", cat: "Symbols" },
        { char: "❓", name: "question mark", keywords: "help ask unknown", cat: "Symbols" },
        { char: "❗", name: "exclamation mark", keywords: "important alert", cat: "Symbols" },
        { char: "💯", name: "hundred points", keywords: "100 perfect score", cat: "Symbols" },
        { char: "🔍", name: "magnifying glass", keywords: "search find zoom", cat: "Symbols" },
        { char: "🔔", name: "bell", keywords: "notification alert ring", cat: "Symbols" },
        { char: "🔕", name: "bell with slash", keywords: "mute silent dnd", cat: "Symbols" },
        { char: "♻️", name: "recycling symbol", keywords: "recycle green", cat: "Symbols" },
        { char: "✨", name: "sparkles", keywords: "shine new magic", cat: "Symbols" },
        { char: "🎵", name: "musical note", keywords: "music song", cat: "Symbols" },
        { char: "©️", name: "copyright", keywords: "legal", cat: "Symbols" },
        { char: "™️", name: "trade mark", keywords: "legal brand", cat: "Symbols" },
        { char: "", name: "apple logo", keywords: "apple mac macos", cat: "Symbols" },

        // ---- Flags ---------------------------------------------------------
        { char: "🏳️‍🌈", name: "rainbow flag", keywords: "pride lgbt", cat: "Flags" },
        { char: "🏁", name: "chequered flag", keywords: "finish race done", cat: "Flags" },
        { char: "🚩", name: "triangular flag", keywords: "red flag warning", cat: "Flags" }
    ]

    // -------------------------------------------------------- frequency ---

    property var frequency: ({})

    FileView {
        id: freqFile
        path: Quickshell.env("HOME") + "/.local/share/vitrum/emoji-usage.json"
        onLoaded: { try { root.frequency = JSON.parse(text()); } catch (e) {} }
        onLoadFailed: root.frequency = ({})
    }

    Timer {
        id: freqWrite
        interval: 2000
        onTriggered: freqFile.setText(JSON.stringify(root.frequency))
    }

    function use(e) {
        const next = Object.assign({}, frequency);
        next[e.char] = (next[e.char] || 0) + 1;
        frequency = next;
        freqWrite.restart();
    }

    readonly property var frequent: {
        const list = all.filter(e => (frequency[e.char] || 0) > 0);
        list.sort((a, b) => (frequency[b.char] || 0) - (frequency[a.char] || 0));
        return list.slice(0, 24);
    }

    // ----------------------------------------------------------- search ---

    function search(q) {
        if (!q) return frequent.length > 0 ? frequent : all.slice(0, 32);
        const ql = q.toLowerCase();
        const scored = [];
        for (const e of all) {
            let s = 0;
            if (e.name === ql) s = 100;
            else if (e.name.indexOf(ql) === 0) s = 80;
            else if (e.name.indexOf(ql) > 0) s = 60;
            else if (e.keywords.split(" ").some(k => k.indexOf(ql) === 0)) s = 50;
            else if (e.keywords.indexOf(ql) >= 0) s = 30;
            if (s === 0) continue;
            scored.push({ e: e, s: s + Math.min(20, (frequency[e.char] || 0) * 4) });
        }
        scored.sort((a, b) => b.s - a.s);
        return scored.map(x => x.e);
    }

    function inCategory(cat) {
        if (cat === "Frequent") return frequent;
        return all.filter(e => e.cat === cat);
    }
}
