import QtQuick
import ".."
import qs.services
import qs.theme
// Package updates waiting (any backend Packages knows). Click: the list, and a way to update.
StatusIcon {
    shown: Packages.updates.length > 0 && !Packages.state.running
    icon: "update"
    label: String(Packages.updates.length)
    panel: "updates"
}
