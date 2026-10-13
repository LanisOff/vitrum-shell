import QtQuick
import qs.theme

// What a widget shows with nothing to show, or something to set up first.
Column {
    property string icon: "help"
    property string text: ""
    anchors.centerIn: parent
    width: parent ? parent.width - 2 * Tokens.gap : 160
    spacing: Tokens.gap * 0.6
    Icon { anchors.horizontalCenter: parent.horizontalCenter; name: parent.icon; size: Tokens.iconSize * 1.8; color: Colors.textDim }
    Label { width: parent.width; text: parent.text; role: "dim"; size: Tokens.textSmall; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; maximumLineCount: 3 }
}
