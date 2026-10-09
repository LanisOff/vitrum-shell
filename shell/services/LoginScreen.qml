pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/wallpaper.js" as WallLib

/*
 * Keeps the login screen (the vitrum SDDM theme) looking like this desktop:
 * ~/.local/share/vitrum/login/ holds the wallpaper's day and night pictures,
 * the palette, and login.json (when day starts and ends, the font). The root
 * helper (vitrum-root login-sync, through pkexec and vitrum's polkit rule)
 * checks them and copies them to /var/lib/vitrum/login/<user>, where the
 * greeter reads them — never from a home it cannot trust.
 */
Singleton {
    id: root
    readonly property bool inShell: !Quickshell.env("VITRUM_NO_THEME")
    readonly property string home: Quickshell.env("HOME")
    // Where the root helper looks (the home in passwd, not XDG_DATA_HOME).
    readonly property string dir: home + "/.local/share/vitrum/login"
    readonly property string palette: (Quickshell.env("XDG_DATA_HOME") || home + "/.local/share") + "/vitrum/palette.json"

    readonly property string wallpaper: String(Settings.get("wallpaper.path", "")).replace(/^~/, home)
    // A video wallpaper: its first frame (the poster Wallpaper puts under the
    // player; made here if it is not there yet). Without one the greeter had
    // no picture and fell back to a gradient.
    readonly property bool video: WallLib.isVideo(wallpaper)
    readonly property string poster: video ? Wallpaper.posters + "/" + Qt.md5(wallpaper) + ".png" : ""
    readonly property var halves: video ? { day: poster, night: poster }
                                        : /\.(jpe?g|png|webp)$/i.test(wallpaper) ? WallLib.halves(wallpaper) : null
    function _hhmm(d, fallback) { return d instanceof Date && !isNaN(d.getTime()) ? Qt.formatTime(d, "HH:mm") : fallback; }
    readonly property var info: ({
        light: _hhmm(Sun.sunrise, Settings.get("scheme.light", "07:00")),
        dark: _hhmm(Sun.sunset, Settings.get("scheme.dark", "19:30")),
        font: Settings.get("fonts.sans", "Inter"),
        h24: Settings.get("clock.h24", true)
    })
    readonly property string wanted: JSON.stringify({ halves: halves, info: info })
    onWantedChanged: if (inShell) later.restart()
    Component.onCompleted: if (inShell) later.restart()
    Timer { id: later; interval: 3000; onTriggered: sync.running = true }

    // Copies, not links: the greeter must be able to read them. A missing
    // night picture is the day one.
    Process {
        id: sync
        command: ["sh", "-c", 'set -e; d="$1"; mkdir -p "$d"; chmod 755 "$d"; ' +
                  'if [ -n "$6" ] && [ ! -s "$2" ]; then mkdir -p "${2%/*}"; ffmpeg -y -loglevel error -ss 0 -i "$6" -frames:v 1 "$2" || true; fi; ' +
                  'if [ -n "$2" ] && [ -f "$2" ]; then install -m 644 "$2" "$d/day.tmp" && mv -f "$d/day.tmp" "$d/day"; ' +
                  '  if [ -f "$3" ]; then install -m 644 "$3" "$d/night.tmp" && mv -f "$d/night.tmp" "$d/night"; else install -m 644 "$2" "$d/night"; fi; ' +
                  'else rm -f "$d/day" "$d/night"; fi; ' +
                  '[ -f "$5" ] && install -m 644 "$5" "$d/palette.json" || true; ' +
                  'printf "%s\\n" "$4" > "$d/login.json.tmp" && chmod 644 "$d/login.json.tmp" && mv -f "$d/login.json.tmp" "$d/login.json"; ' +
                  // The helper reads the home in passwd: from any other HOME (a test session) asking is pointless.
                  'h=/usr/local/libexec/vitrum/vitrum-root; [ -x "$h" ] && [ "$HOME" = "$(getent passwd "$(id -u)" | cut -d: -f6)" ] && pkexec "$h" login-sync || true',
                  "_", root.dir, root.halves ? root.halves.day : "", root.halves ? root.halves.night : "", JSON.stringify(root.info), root.palette,
                  root.video ? root.wallpaper : ""]
    }
    // A new palette (a new wallpaper, a scheme flip) comes after the picture.
    FileView {
        path: root.palette
        watchChanges: true
        printErrors: false
        onFileChanged: if (root.inShell) later.restart()
    }
}
