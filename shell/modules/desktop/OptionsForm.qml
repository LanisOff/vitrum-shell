import QtQuick
import qs.theme
import qs.components

/*
 * A widget's options, as a form built from its schema (lib/widgets.js):
 * bool → a switch, choice and color → choices (the chosen one tinted),
 * number → a stepper, text and
 * folder → a field (saved on Enter or leaving it), list → chips with × (a
 * click on one's text renames it in place) and a field to add. Options
 * marked hidden (a note's text) are not shown.
 * `changed` hands back the whole options object, one value changed.
 */
Column {
    id: form
    property var schema: []
    property var values: ({})
    /// Whose options these are: handed back with each change.
    property string targetId: ""
    signal changed(string id, var options)
    function put(key, value) { putFor(form.targetId, form.values, key, value); }
    // A field that saves when it loses focus saves for the widget it was
    // typing for, not whichever is selected by then.
    function putFor(id, base, key, value) {
        const o = Object.assign({}, base);
        o[key] = value;
        form.changed(id, o);
    }
    spacing: Tokens.gap * 1.2

    Repeater {
        model: form.schema.filter(o => !o.hidden)
        delegate: Column {
            id: field
            required property var modelData
            readonly property var opt: modelData
            readonly property var value: form.values[opt.key]
            width: form.width
            spacing: Tokens.gap * 0.5
            // A switch sits beside its label; everything else under it.
            Item {
                width: parent.width
                height: Math.max(head.implicitHeight, field.opt.type === "bool" ? sw.implicitHeight : 0)
                Column {
                    id: head
                    width: parent.width - (field.opt.type === "bool" ? sw.width + Tokens.gap : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    Label { width: parent.width; text: field.opt.label; font.weight: Font.Medium; elide: Text.ElideRight }
                    Label { width: parent.width; visible: !!field.opt.hint; text: field.opt.hint || ""; role: "dim"; size: Tokens.textSmall; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                }
                GlassSwitch {
                    id: sw
                    visible: field.opt.type === "bool"
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    checked: field.value === true
                    onToggled: form.put(field.opt.key, !checked)
                }
            }
            Loader {
                width: parent.width
                active: field.opt.type !== "bool"
                sourceComponent: field.opt.type === "choice" || field.opt.type === "color" ? chips
                               : field.opt.type === "number" ? stepper
                               : field.opt.type === "list" ? list : text
                property var opt: field.opt
                property var value: field.value
            }
        }
    }

    // ---------------------------------------------------------- controls ---
    Component {
        id: chips
        Flow {
            id: flow
            readonly property var opt: parent.opt
            readonly property var value: parent.value
            spacing: 6
            Repeater {
                model: flow.opt.choices || []
                delegate: GlassChoice {
                    required property var modelData
                    label: modelData.label
                    chosen: modelData.value === flow.value
                    swatch: flow.opt.type !== "color" ? "transparent"
                          : modelData.value === "accent" ? Colors.accent : Colors.ink(Number(modelData.value))
                    onClicked: form.put(flow.opt.key, modelData.value)
                }
            }
        }
    }
    Component {
        id: stepper
        Row {
            id: st
            readonly property var opt: parent.opt
            readonly property real value: Number(parent.value)
            readonly property real step: opt.step || 1
            spacing: Tokens.gap
            function to(v) {
                const lo = opt.min !== undefined ? opt.min : -Infinity, hi = opt.max !== undefined ? opt.max : Infinity;
                form.put(opt.key, Math.max(lo, Math.min(hi, Math.round(v / step) * step)));
            }
            StepButton { icon: "remove"; enabled: st.opt.min === undefined || st.value > st.opt.min; onClicked: st.to(st.value - st.step) }
            Label { width: Tokens.islandHeight * 1.6; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter; text: String(st.value); numeric: true; font.weight: Font.Medium }
            StepButton { icon: "add"; enabled: st.opt.max === undefined || st.value < st.opt.max; onClicked: st.to(st.value + st.step) }
        }
    }
    Component {
        id: text
        Field {
            readonly property var opt: parent.opt
            width: parent.width
            text: String(parent.value === undefined ? "" : parent.value)
            placeholder: opt.type === "folder" ? "~/Pictures" : ""
            onCommitted: (v, id, base) => { if (v !== String(base[opt.key] === undefined ? "" : base[opt.key])) form.putFor(id, base, opt.key, v); }
        }
    }
    Component {
        id: list
        Flow {
            id: lf
            readonly property var opt: parent.opt
            readonly property var items: Array.isArray(parent.value) ? parent.value : []
            width: parent.width
            spacing: 6
            Repeater {
                model: lf.items
                // A chip: a click on its text renames it in place (the same
                // position, so a widget can tell a rename from a new entry).
                delegate: Surface {
                    id: chip
                    required property var modelData
                    required property int index
                    property bool renaming: false
                    height: Tokens.islandHeight; radius: Tokens.radiusButton
                    width: renaming ? Math.min(lf.width, Tokens.islandHeight * 6) : Math.min(lf.width, lr.implicitWidth + Tokens.padding * 1.2)
                    level: 2
                    Row {
                        id: lr
                        // Hidden by opacity, not visibility: its width must stay measured.
                        opacity: chip.renaming ? 0 : 1
                        enabled: !chip.renaming
                        anchors.centerIn: parent
                        spacing: 4
                        Label { text: String(modelData); size: Tokens.textSmall + 1; anchors.verticalCenter: parent.verticalCenter
                                MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: chip.renaming = true } }
                        Icon { name: "close"; size: Tokens.textSmall + 3; anchors.verticalCenter: parent.verticalCenter
                               MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor
                                           onClicked: { const l = lf.items.slice(); l.splice(index, 1); form.put(lf.opt.key, l); } } }
                    }
                    Loader {
                        anchors.fill: parent
                        active: chip.renaming
                        sourceComponent: Field {
                            text: String(chip.modelData)
                            Component.onCompleted: focusIn()
                            // Enter or leaving the field saves it (once); blank or taken: no change.
                            onCommitted: (v, id, base) => {
                                if (!chip.renaming) return;
                                chip.renaming = false;
                                const cur = Array.isArray(base[lf.opt.key]) ? base[lf.opt.key] : lf.items, t = v.trim();
                                if (!t || t === String(chip.modelData) || cur.indexOf(t) >= 0) return;
                                const l = cur.slice(); l[chip.index] = t;
                                form.putFor(id, base, lf.opt.key, l);
                            }
                        }
                    }
                }
            }
            Field {
                width: Math.min(lf.width, Tokens.islandHeight * 6)
                placeholder: "Add…"
                clearOnCommit: true
                onCommitted: v => { const s = v.trim(); if (s && lf.items.indexOf(s) < 0) form.put(lf.opt.key, lf.items.concat([s])); }
            }
        }
    }

    // A text field: a faint well in the glass, an accent rim while typing.
    component Field: Rectangle {
        id: fld
        property alias text: input.text
        property string placeholder: ""
        property bool clearOnCommit: false
        // Whose value is being typed: taken when the field gets the focus.
        property string forId: ""
        property var forValues: ({})
        signal committed(string value, string id, var base)
        function focusIn() { input.forceActiveFocus(); input.selectAll(); }
        height: Tokens.islandHeight * 1.1
        radius: Tokens.radiusButton
        color: Colors.alpha(Colors.text, 0.07)
        border.width: input.activeFocus ? 2 : 0; border.color: Colors.accent
        TextInput {
            id: input
            anchors { fill: parent; leftMargin: Tokens.gap; rightMargin: Tokens.gap }
            verticalAlignment: TextInput.AlignVCenter
            font.family: Tokens.fontText; font.pixelSize: Tokens.textSize
            color: Colors.text; selectionColor: Colors.accent
            clip: true
            function commit() { fld.committed(text, fld.forId, fld.forValues); if (fld.clearOnCommit) text = ""; }
            onAccepted: commit()
            onActiveFocusChanged: {
                if (activeFocus) { fld.forId = form.targetId; fld.forValues = form.values; }
                else if (!fld.clearOnCommit) commit();
            }
            Label { visible: !input.text && !input.activeFocus; text: fld.placeholder; role: "dim"; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    // The stepper's − and +: square glass buttons, dimmed at the ends.
    component StepButton: GlassButton {
        width: Tokens.islandHeight; height: width
    }
}
