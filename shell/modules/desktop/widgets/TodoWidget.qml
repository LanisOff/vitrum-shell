import QtQuick
import qs.services
import qs.theme
import qs.components

/*
 * A to-do list, kept in the widget's options (a done item starts with "[x] ").
 *   S   how many are left, big; the first of them under it, ticked off by a click
 *   M/L the header (the title, how many left); the items, a click ticks one
 *       off or back, × on hover removes it; a field at the bottom adds one
 * options: title, hideDone, items (hidden from the form).
 * In a gallery card a sample list stands in, and nothing is saved.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    readonly property string mark: "[x] "
    // A local copy, so a click shows at once, before the saved options come back.
    property var items: []
    function load() {
        items = preview ? ["[x] Water the plants", "Call the bank", "Buy coffee", "Book the train"]
                        : (options.items || []).slice();
    }
    onOptionsChanged: load()
    onPreviewChanged: load()
    Component.onCompleted: load()

    readonly property var entries: items.map((s, i) => ({ i: i, done: s.indexOf(mark) === 0, text: s.indexOf(mark) === 0 ? s.slice(mark.length) : s }))
    readonly property var shown: options.hideDone === true ? entries.filter(e => !e.done) : entries
    readonly property var open: entries.filter(e => !e.done)

    function save(next) {
        items = next;
        if (!preview) optionsEdited(Object.assign({}, options, { items: next }));
    }
    function toggle(i) {
        const n = items.slice(), s = n[i];
        n[i] = s.indexOf(mark) === 0 ? s.slice(mark.length) : mark + s;
        save(n);
    }
    function remove(i) { const n = items.slice(); n.splice(i, 1); save(n); }
    function add(text) {
        const t = String(text || "").trim();
        if (t) save(items.concat([t]));
    }

    WidgetHeader {
        id: head
        visible: root.sizeClass !== "S"
        height: visible ? implicitHeight : 0
        icon: "todo"; title: root.options.title || "To-do"
        trailing: root.items.length ? (root.open.length ? root.open.length + " left" : "All done") : ""
    }

    // ---- S: what is left.
    Column {
        visible: root.sizeClass === "S"
        anchors.centerIn: parent
        width: root.width
        spacing: Tokens.gap * 0.4
        Metric {
            anchors.horizontalCenter: parent.horizontalCenter
            value: String(root.open.length)
            unit: "left"
            size: Math.round(root.height * 0.32)
            color: root.open.length ? Colors.text : Colors.textDim
        }
        Item {
            width: parent.width
            height: Tokens.textSize * 1.8
            Row {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width)
                spacing: 6
                Icon {
                    id: firstBox
                    visible: root.open.length > 0
                    name: "checkbox-blank"
                    size: Tokens.textSize + 2
                    color: firstMouse.containsMouse ? Colors.accent : Colors.textDim
                    anchors.verticalCenter: parent.verticalCenter
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, root.width - firstBox.width - 6)
                    text: root.open.length ? root.open[0].text : root.items.length ? "All done" : "Nothing to do"
                    role: root.open.length ? "text" : "dim"
                    size: Tokens.textSmall + 1
                }
            }
            MouseArea {
                id: firstMouse
                anchors.fill: parent
                enabled: root.open.length > 0
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggle(root.open[0].i)
            }
        }
    }

    // ---- M and L: the list.
    ListView {
        id: list
        visible: root.sizeClass !== "S"
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: Tokens.gap * 0.4; bottom: field.top; bottomMargin: Tokens.gap * 0.5 }
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.shown
        delegate: Item {
            id: row
            required property var modelData
            width: list.width
            height: Math.round(Tokens.textSize * 2.1)
            Rectangle {
                anchors.fill: parent
                radius: Tokens.radiusInner
                color: Colors.alpha(Colors.text, rowMouse.containsMouse ? 0.06 : 0)
                Behavior on color { enabled: Motion.enabled; ColorAnim {} }
            }
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggle(row.modelData.i)
            }
            Icon {
                id: box
                x: 4
                anchors.verticalCenter: parent.verticalCenter
                name: row.modelData.done ? "checkbox" : "checkbox-blank"
                filled: row.modelData.done
                size: Tokens.textSize + 4
                color: row.modelData.done ? Colors.accent : Colors.textDim
            }
            Label {
                anchors { left: box.right; leftMargin: Tokens.gap * 0.6; right: del.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
                text: row.modelData.text
                role: row.modelData.done ? "dim" : "text"
                font.strikeout: row.modelData.done
            }
            Icon {
                id: del
                anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                name: "close"
                size: Tokens.textSize + 2
                opacity: rowMouse.containsMouse || delMouse.containsMouse ? 1 : 0
                color: delMouse.containsMouse ? Colors.danger : Colors.textDim
                Behavior on opacity { enabled: Motion.enabled; EaseAnim {} }
                MouseArea {
                    id: delMouse
                    anchors.fill: parent; anchors.margins: -4
                    enabled: parent.opacity > 0
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.remove(row.modelData.i)
                }
            }
        }
        Label {
            anchors.centerIn: parent
            visible: list.count === 0
            text: root.items.length ? "All done" : "Nothing to do"
            role: "dim"; size: Tokens.textSmall
        }
    }

    // ---- the add field.
    Rectangle {
        id: field
        visible: root.sizeClass !== "S"
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: visible ? Math.round(Tokens.islandHeight * 0.95) : 0
        radius: Tokens.radiusInner
        color: Colors.alpha(Colors.text, input.activeFocus ? 0.10 : 0.06)
        border.width: input.activeFocus ? 1 : 0
        border.color: Colors.alpha(Colors.accent, 0.6)
        Icon {
            id: plus
            x: Tokens.gap * 0.6
            anchors.verticalCenter: parent.verticalCenter
            name: "add"
            size: Tokens.textSize + 2
            color: input.activeFocus ? Colors.accent : Colors.textDim
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: input.forceActiveFocus()
        }
        TextInput {
            id: input
            anchors { left: plus.right; leftMargin: Tokens.gap * 0.5; right: parent.right; rightMargin: Tokens.gap * 0.6; verticalCenter: parent.verticalCenter }
            font.family: Tokens.fontText
            font.pixelSize: Tokens.textSize
            color: Colors.text
            selectionColor: Colors.accent
            selectedTextColor: Colors.onAccent
            selectByMouse: true
            clip: true
            readOnly: root.preview
            onAccepted: { root.add(text); text = ""; }
            Keys.onEscapePressed: { text = ""; focus = false; }
            Label {
                visible: input.text.length === 0
                anchors.verticalCenter: parent.verticalCenter
                text: "Add an item"
                role: "dim"
            }
        }
    }
}
