import QtQuick
import ".."
import qs.services
import qs.theme
import "../../../lib/text.js" as TextLib
// A coffee cup while the computer stays awake; the minutes left when timed.
StatusIcon {
    shown: Awake.active
    icon: "coffee"
    tint: Colors.accent
    filled: Awake.manual
    label: Awake.mode === "timed" ? Math.ceil(Awake.remaining / 60) + "m" : ""
}
