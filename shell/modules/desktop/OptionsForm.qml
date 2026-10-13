import QtQuick
import qs.theme
import qs.components

/*
 * A widget's options, as a form built from its schema (lib/widgets.js):
 * bool → a switch, choice and color → chips, number → a stepper, text and
 * folder → a field (saved on Enter or leaving it), list → chips with × and a
 * field to add. Options marked hidden (a note's text) are not shown.
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
                Toggle {
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
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: modelData.value === flow.value
                    readonly property bool swatch: flow.opt.type === "color"
                    height: Tokens.islandHeight * 1.0
                    width: chipRow.implicitWidth + Tokens.padding * 1.3
                    radius: Tokens.radiusInner
                    color: on ? Colors.alpha(Colors.accent, Colors.dark ? 0.32 : 0.22) : chipMouse.containsMouse ? Colors.alpha(Colors.text, 0.1) : "transparent"
                    border.width: on ? 0 : Tokens.hairline; border.color: Colors.alpha(Colors.text, 0.25)
                    Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 6
                        Icon { visible: on && !swatch; name: "check"; size: Tokens.textSmall + 4; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle {
                            visible: swatch
                            width: Tokens.textSmall + 4; height: width; radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: modelData.value === "accent" ? Colors.accent : Colors.ink(Number(modelData.value))
                        }
                        Label { text: modelData.label; size: Tokens.textSmall + 1; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: form.put(flow.opt.key, modelData.value) }
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
            RoundButton { icon: "remove"; enabled: st.opt.min === undefined || st.value > st.opt.min; onClicked: st.to(st.value - st.step) }
            Label { width: Tokens.islandHeight * 1.6; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter; text: String(st.value); numeric: true; font.weight: Font.Medium }
            RoundButton { icon: "add"; enabled: st.opt.max === undefined || st.value < st.opt.max; onClicked: st.to(st.value + st.step) }
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
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    height: Tokens.islandHeight; radius: Tokens.radiusInner
                    width: Math.min(lf.width, lr.implicitWidth + Tokens.padding * 1.2)
                    color: Colors.alpha(Colors.accent, 0.16)
                    Row {
                        id: lr
                        anchors.centerIn: parent
                        spacing: 4
                        Label { text: String(modelData); size: Tokens.textSmall + 1; anchors.verticalCenter: parent.verticalCenter }
                        Icon { name: "close"; size: Tokens.textSmall + 3; anchors.verticalCenter: parent.verticalCenter
                               MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor
                                           onClicked: { const l = lf.items.slice(); l.splice(index, 1); form.put(lf.opt.key, l); } } }
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

    // A Material text field: a tonal well, an accent rim while typing.
    component Field: Rectangle {
        id: fld
        property alias text: input.text
        property string placeholder: ""
        property bool clearOnCommit: false
        // Whose value is being typed: taken when the field gets the focus.
        property string forId: ""
        property var forValues: ({})
        signal committed(string value, string id, var base)
        height: Tokens.islandHeight * 1.1
        radius: Tokens.radiusInner
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
    component RoundButton: Rectangle {
        id: rb
        property string icon: ""
        signal clicked()
        width: Tokens.islandHeight; height: width; radius: width / 2
        opacity: enabled ? 1 : 0.4
        color: rbMouse.containsMouse ? Colors.alpha(Colors.text, 0.14) : Colors.alpha(Colors.text, 0.07)
        Icon { anchors.centerIn: parent; name: rb.icon }
        MouseArea { id: rbMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rb.clicked() }
    }
}
