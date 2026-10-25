import QtQuick
import ".."
import qs.services
import qs.theme
// Unread count; click: the notification centre flows out of this island.
StatusIcon {
    icon: "notifications"
    label: Notifs.unreadCount > 0 ? String(Notifs.unreadCount) : ""
    panel: "notifications"
}
