import QtQuick
import ".."
import qs.services
import qs.theme
// Packages waiting in @world (after a sync). Click: the list, and a way to update.
StatusIcon {
    shown: Packages.updates.length > 0 && !Packages.state.running
    icon: "update"
    label: String(Packages.updates.length)
    panel: "updates"
}
