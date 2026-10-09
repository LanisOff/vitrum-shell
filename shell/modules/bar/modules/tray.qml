import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.services
import qs.theme
import ".."

// The system tray — on the primary screen only (two trays duplicate icons and confuse menus).
BarModule {
    id: root
    shown: primary && SystemTray.items.values.length > 0
    hoverable: false
    implicitWidth: row.implicitWidth
    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.gap / 2
        Repeater {
            model: SystemTray.items
            delegate: IconImage {
                id: icon
                required property SystemTrayItem modelData
                source: modelData.icon
                implicitSize: Tokens.iconSize
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: m => {
                        const it = icon.modelData;
                        if (m.button === Qt.MiddleButton) it.secondaryActivate();
                        else if (m.button === Qt.RightButton || it.onlyMenu) {
                            if (!it.hasMenu) return;
                            // Open: the same item closes its menu, another one takes the panel over.
                            if (UiState.panel === "tray") {
                                if (UiState.trayItem === it) UiState.closePanel(); else UiState.trayItem = it;
                                return;
                            }
                            UiState.trayItem = it;
                            const src = root.island || icon;
                            const p = src.mapToItem(null, 0, 0);
                            UiState.openPanel("tray", root.screen, Qt.rect(p.x, p.y, src.width, src.height), root.island);
                        } else it.activate();
                    }
                    onWheel: w => icon.modelData.scroll(w.angleDelta.y, false)
                }
            }
        }
    }
}
