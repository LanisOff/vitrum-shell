import QtQuick
import qs.services
import qs.theme
import qs.components

// What is new in vitrum since this install: the commits, and Update (vitrum
// update in a terminal: a snapshot first, then only what changed is rebuilt).
Column {
    id: root
    spacing: Tokens.gap
    width: Tokens.islandHeight * 13

    Row {
        width: root.width
        spacing: Tokens.gap
        Column {
            width: parent.width - up.width - Tokens.gap
            anchors.verticalCenter: parent.verticalCenter
            Label {
                font.weight: Font.DemiBold
                text: VitrumUpdate.behind === 1 ? "1 new commit in vitrum" : VitrumUpdate.behind + " new commits in vitrum"
            }
            Label { width: parent.width; text: VitrumUpdate.url.replace(/^https?:\/\//, ""); role: "dim"; size: Tokens.textSmall; elide: Text.ElideMiddle }
        }
        Capsule { id: up; icon: "vitrum-update"; label: "Update"; active: true; anchors.verticalCenter: parent.verticalCenter
                  onClicked: { UiState.closePanel(); VitrumUpdate.update(); } }
    }
    Flickable {
        width: root.width
        height: Math.min(contentHeight, Tokens.islandHeight * 9)
        contentHeight: list.implicitHeight
        clip: true
        Column {
            id: list
            width: root.width
            spacing: 2
            Repeater {
                model: VitrumUpdate.commits
                Row {
                    required property var modelData
                    width: list.width
                    spacing: Tokens.gap
                    Label { text: modelData.hash; role: "dim"; size: Tokens.textSmall; numeric: true; anchors.verticalCenter: parent.verticalCenter }
                    Label { width: parent.width - Tokens.islandHeight * 5.2; text: modelData.subject; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                    Label { text: modelData.when; role: "dim"; size: Tokens.textSmall; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
    Label {
        visible: VitrumUpdate.behind > VitrumUpdate.commits.length
        text: "and " + (VitrumUpdate.behind - VitrumUpdate.commits.length) + " more"
        role: "dim"; size: Tokens.textSmall
    }
}
