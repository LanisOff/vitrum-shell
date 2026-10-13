import QtQuick
import qs.theme

// A big number, its unit a step smaller beside it, an optional label under:
// the one thing a widget is about, in light weight with tabular figures.
Column {
    id: root
    property string value: ""
    property string unit: ""
    property string label: ""
    property int size: 40
    property color color: Colors.text
    spacing: 0
    Row {
        spacing: Math.round(root.size * 0.08)
        Label {
            id: big
            text: root.value
            size: root.size
            numeric: true
            font.weight: Font.Light
            color: root.color
            elide: Text.ElideNone
        }
        Label {
            visible: root.unit.length > 0
            text: root.unit
            size: Math.max(Tokens.textSmall, Math.round(root.size * 0.42))
            role: "dim"
            // On the number's baseline (a Row allows no anchors).
            y: big.baselineOffset - baselineOffset
        }
    }
    // Its own width: bound to the column's, the column grew without end.
    Label { visible: root.label.length > 0; text: root.label; role: "dim"; size: Tokens.textSmall; elide: Text.ElideNone }
}
