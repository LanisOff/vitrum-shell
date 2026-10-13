import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components
import "../../lib/widgets.js" as W

/*
 * The widget editor's side sheet (Material 3): a tonal container with big
 * corners, three tabs as a segmented button —
 *   Gallery   every widget as a card with a live preview; search, categories
 *   Selected  the selection: sizes, options (OptionsForm), screen, duplicate,
 *             remove; for several, align and distribute
 *   Custom    your own widgets (CustomTab)
 * — and the session's buttons at the bottom: undo, redo, Cancel, Done.
 */
Surface {
    id: sheet
    property string screenName: ""
    property int barSpace: 0
    signal cardDragged(point windowPos)
    signal cardDropped(string type, point windowPos)

    group: "panels"
    level: 1
    radius: 28
    // Clicks in the sheet stay in it (the backdrop under it clears the selection).
    MouseArea { anchors.fill: parent }

    readonly property real pad: Tokens.padding * 1.4
    readonly property string tab: WidgetEditor.tab

    Column {
        id: head
        x: sheet.pad; y: sheet.pad
        width: sheet.width - 2 * sheet.pad
        spacing: Tokens.gap
        Label { text: "Widgets"; size: Tokens.textTitle; font.weight: Font.DemiBold }
        Label {
            width: parent.width
            text: sheet.tab === "gallery" ? "Click a widget to add it, or drag it onto a desktop."
                : sheet.tab === "selected" ? "Shift-click or drag a box to select several."
                : "Widgets you make: a command, or QML of your own."
            role: "dim"; size: Tokens.textSmall + 1; wrapMode: Text.WordWrap; elide: Text.ElideNone
        }
        // The segmented button.
        Rectangle {
            width: parent.width
            height: Tokens.islandHeight * 1.15
            radius: height / 2
            color: "transparent"
            border.width: Tokens.hairline; border.color: Colors.alpha(Colors.text, 0.3)
            Row {
                anchors.fill: parent
                Repeater {
                    model: [{ t: "gallery", l: "Gallery", i: "widgets" }, { t: "selected", l: "Selected", i: "select" }, { t: "custom", l: "Custom", i: "code" }]
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool on: sheet.tab === modelData.t
                        width: parent.width / 3; height: parent.height
                        radius: height / 2
                        color: on ? Colors.alpha(Colors.accent, Colors.dark ? 0.32 : 0.22) : segMouse.containsMouse ? Colors.alpha(Colors.text, 0.07) : "transparent"
                        Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Icon { name: on ? "check" : modelData.i; size: Tokens.textSize + 2; anchors.verticalCenter: parent.verticalCenter }
                            Label { text: modelData.l; font.weight: Font.Medium; size: Tokens.textSmall + 1; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { id: segMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: WidgetEditor.tab = modelData.t }
                    }
                }
            }
        }
    }

    Item {
        id: body
        anchors { top: head.bottom; topMargin: Tokens.gap * 1.4; bottom: foot.top; bottomMargin: Tokens.gap; left: parent.left; right: parent.right; leftMargin: sheet.pad; rightMargin: sheet.pad }
        clip: true

        // ------------------------------------------------------ gallery ---
        Item {
            anchors.fill: parent
            visible: sheet.tab === "gallery"
            property string query: ""
            property string cat: "all"
            id: gallery
            readonly property var cats: [
                { c: "all", l: "All" }, { c: "time", l: "Time" }, { c: "productivity", l: "Productivity" },
                { c: "system", l: "System" }, { c: "media", l: "Media" }, { c: "apps", l: "Apps" }, { c: "custom", l: "Custom" }]
            readonly property var types: {
                const all = W.types().concat(Object.keys(WidgetEditor.custom));
                const q = query.trim().toLowerCase();
                return all.filter(t => {
                    const m = W.meta(t, WidgetEditor.custom);
                    return (cat === "all" || m.category === cat) && (!q || m.name.toLowerCase().indexOf(q) >= 0);
                });
            }
            Rectangle {
                id: search
                width: parent.width; height: Tokens.islandHeight * 1.2; radius: height / 2
                color: Colors.alpha(Colors.text, 0.07)
                border.width: searchInput.activeFocus ? 2 : 0; border.color: Colors.accent
                Icon { id: searchIcon; name: "search"; x: Tokens.gap * 1.2; anchors.verticalCenter: parent.verticalCenter; color: Colors.textDim }
                TextInput {
                    id: searchInput
                    anchors { left: searchIcon.right; leftMargin: Tokens.gap; right: parent.right; rightMargin: Tokens.gap * 1.2; verticalCenter: parent.verticalCenter }
                    font.family: Tokens.fontText; font.pixelSize: Tokens.textSize
                    color: Colors.text; selectionColor: Colors.accent; clip: true
                    onTextChanged: gallery.query = text
                    Label { visible: !searchInput.text; text: "Search widgets"; role: "dim"; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            Flow {
                id: catRow
                anchors { top: search.bottom; topMargin: Tokens.gap }
                width: parent.width
                spacing: 6
                Repeater {
                    model: gallery.cats
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool on: gallery.cat === modelData.c
                        height: Tokens.islandHeight * 0.95; radius: Tokens.radiusInner
                        width: catLabel.implicitWidth + Tokens.padding * 1.2
                        color: on ? Colors.alpha(Colors.accent, Colors.dark ? 0.32 : 0.22) : catMouse.containsMouse ? Colors.alpha(Colors.text, 0.08) : "transparent"
                        border.width: on ? 0 : Tokens.hairline; border.color: Colors.alpha(Colors.text, 0.25)
                        Label { id: catLabel; anchors.centerIn: parent; text: modelData.l; size: Tokens.textSmall + 1 }
                        MouseArea { id: catMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: gallery.cat = modelData.c }
                    }
                }
            }
            GridView {
                id: grid
                anchors { top: catRow.bottom; topMargin: Tokens.gap; bottom: parent.bottom }
                width: parent.width
                clip: true
                cellWidth: width / 2
                cellHeight: Math.round(cellWidth * 0.86)
                model: gallery.types
                cacheBuffer: 0
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    required property var modelData
                    width: grid.cellWidth; height: grid.cellHeight
                    GalleryCard {
                        anchors { fill: parent; margins: 5 }
                        type: modelData
                        onClicked: WidgetEditor.addType(modelData, sheet.screenName, sheet.barSpace)
                        onDragged: p => sheet.cardDragged(p)
                        onDropped: p => sheet.cardDropped(modelData, p)
                    }
                }
            }
        }

        // ----------------------------------------------------- selected ---
        Flickable {
            anchors.fill: parent
            visible: sheet.tab === "selected"
            contentHeight: selCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: selCol
                width: parent.width
                spacing: Tokens.gap * 1.4
                readonly property var sel: WidgetEditor.selection
                readonly property var one: sel.length === 1 ? WidgetEditor.all.find(i => i.id === sel[0]) || null : null
                readonly property var oneMeta: one ? W.meta(one.type, WidgetEditor.custom) : null

                WidgetEmpty { visible: selCol.sel.length === 0; anchors.centerIn: undefined; icon: "select"; text: "Select a widget on a desktop to change it." }

                // One widget.
                Row {
                    visible: !!selCol.one
                    spacing: Tokens.gap
                    Rectangle {
                        width: Tokens.islandHeight * 1.3; height: width; radius: width / 2
                        color: Colors.alpha(Colors.accent, Colors.dark ? 0.22 : 0.16)
                        Icon { anchors.centerIn: parent; name: selCol.oneMeta ? selCol.oneMeta.icon : "help"; color: Colors.accent; filled: true; size: Tokens.iconSize * 1.2 }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Label { text: selCol.oneMeta ? selCol.oneMeta.name : ""; size: Tokens.textLarge; font.weight: Font.DemiBold }
                        Label { text: selCol.one ? Math.round(selCol.one.w) + " × " + Math.round(selCol.one.h) + "  ·  " + selCol.one.output : ""; role: "dim"; size: Tokens.textSmall; numeric: true }
                    }
                }
                Column {
                    visible: !!selCol.one
                    width: parent.width
                    spacing: Tokens.gap * 0.6
                    Label { text: "Size"; font.weight: Font.Medium }
                    Row {
                        spacing: 6
                        Repeater {
                            model: selCol.oneMeta ? selCol.oneMeta.sizes : []
                            delegate: Rectangle {
                                required property string modelData
                                readonly property bool on: selCol.one && W.sizeClass(selCol.one.w, selCol.one.h) === modelData
                                width: Tokens.islandHeight * 1.5; height: Tokens.islandHeight * 1.1; radius: Tokens.radiusInner
                                color: on ? Colors.alpha(Colors.accent, Colors.dark ? 0.32 : 0.22) : presetMouse.containsMouse ? Colors.alpha(Colors.text, 0.08) : "transparent"
                                border.width: on ? 0 : Tokens.hairline; border.color: Colors.alpha(Colors.text, 0.25)
                                Label { anchors.centerIn: parent; text: modelData; font.weight: Font.DemiBold }
                                MouseArea { id: presetMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: WidgetEditor.setPreset(selCol.one.id, modelData) }
                            }
                        }
                    }
                }
                OptionsForm {
                    visible: !!selCol.one && schema.filter(o => !o.hidden).length > 0
                    width: parent.width
                    schema: selCol.oneMeta ? selCol.oneMeta.options || [] : []
                    values: selCol.one ? W.withDefaults(selCol.one.type, selCol.one.options, WidgetEditor.custom) : ({})
                    targetId: selCol.one ? selCol.one.id : ""
                    onChanged: (id, o) => { if (id) WidgetEditor.setOptions(id, o); }
                }
                Column {
                    visible: !!selCol.one && Quickshell.screens.length > 1
                    width: parent.width
                    spacing: Tokens.gap * 0.6
                    Label { text: "Screen"; font.weight: Font.Medium }
                    Flow {
                        width: parent.width
                        spacing: 6
                        Repeater {
                            model: Quickshell.screens.map(s => s.name)
                            delegate: Rectangle {
                                required property string modelData
                                readonly property bool on: selCol.one && selCol.one.output === modelData
                                height: Tokens.islandHeight; radius: Tokens.radiusInner
                                width: scrLabel.implicitWidth + Tokens.padding * 1.2
                                color: on ? Colors.alpha(Colors.accent, Colors.dark ? 0.32 : 0.22) : scrMouse.containsMouse ? Colors.alpha(Colors.text, 0.08) : "transparent"
                                border.width: on ? 0 : Tokens.hairline; border.color: Colors.alpha(Colors.text, 0.25)
                                Label { id: scrLabel; anchors.centerIn: parent; text: modelData; size: Tokens.textSmall + 1 }
                                MouseArea { id: scrMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: if (!on) WidgetEditor.moveToOutput(selCol.one.id, modelData, { x: selCol.one.x, y: selCol.one.y }) }
                            }
                        }
                    }
                }

                // Several.
                Label { visible: selCol.sel.length > 1; text: selCol.sel.length + " widgets"; size: Tokens.textLarge; font.weight: Font.DemiBold }
                Column {
                    visible: selCol.sel.length > 1
                    width: parent.width
                    spacing: Tokens.gap * 0.6
                    Label { text: "Align"; font.weight: Font.Medium }
                    Row {
                        spacing: 6
                        Repeater {
                            model: [["left", "align-left"], ["hcenter", "align-hcenter"], ["right", "align-right"], ["top", "align-top"], ["vcenter", "align-vcenter"], ["bottom", "align-bottom"]]
                            delegate: IconButton { required property var modelData; icon: modelData[1]; onClicked: WidgetEditor.alignSelected(modelData[0]) }
                        }
                    }
                    Label { text: "Distribute"; font.weight: Font.Medium; visible: selCol.sel.length > 2 }
                    Row {
                        visible: selCol.sel.length > 2
                        spacing: 6
                        IconButton { icon: "distribute-h"; onClicked: WidgetEditor.distributeSelected("h") }
                        IconButton { icon: "distribute-v"; onClicked: WidgetEditor.distributeSelected("v") }
                    }
                }
                Row {
                    visible: selCol.sel.length > 0
                    spacing: Tokens.gap
                    TextButton { icon: "duplicate"; text: "Duplicate"; tonal: true; onClicked: WidgetEditor.duplicateSelected() }
                    TextButton { icon: "trash"; text: "Remove"; danger: true; onClicked: WidgetEditor.removeSelected() }
                }
            }
        }

        // ------------------------------------------------------- custom ---
        Loader {
            anchors.fill: parent
            active: sheet.tab === "custom"
            visible: active
            source: "CustomTab.qml"
            onLoaded: { item.screenName = Qt.binding(() => sheet.screenName); item.barSpace = Qt.binding(() => sheet.barSpace); }
        }
    }

    // ------------------------------------------------------------ footer ---
    Row {
        id: foot
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: sheet.pad }
        height: Tokens.islandHeight * 1.2
        spacing: 6
        IconButton { icon: "undo"; enabled: WidgetEditor.canUndo; onClicked: WidgetEditor.undo(); anchors.verticalCenter: parent.verticalCenter }
        IconButton { icon: "redo"; enabled: WidgetEditor.canRedo; onClicked: WidgetEditor.redo(); anchors.verticalCenter: parent.verticalCenter }
        Item { width: parent.width - 4 * 6 - 2 * Tokens.islandHeight * 1.1 - cancelBtn.width - doneBtn.width; height: 1 }
        // The focus first: a field being typed in saves into the draft, which
        // Done then keeps and Cancel drops.
        TextButton {
            id: cancelBtn
            text: "Cancel"; tonal: true
            anchors.verticalCenter: parent.verticalCenter
            onClicked: { sheet.forceActiveFocus(); WidgetEditor.cancel(); }
        }
        TextButton {
            id: doneBtn
            text: "Done"; filled: true
            anchors.verticalCenter: parent.verticalCenter
            onClicked: { sheet.forceActiveFocus(); WidgetEditor.done(); }
        }
    }

    component IconButton: Rectangle {
        id: ib
        property string icon: ""
        signal clicked()
        width: Tokens.islandHeight * 1.1; height: width; radius: width / 2
        opacity: enabled ? 1 : 0.38
        color: ibMouse.containsMouse && enabled ? Colors.alpha(Colors.text, 0.12) : Colors.alpha(Colors.text, 0.05)
        Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
        Icon { anchors.centerIn: parent; name: ib.icon }
        MouseArea { id: ibMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ib.clicked() }
    }
    component TextButton: Rectangle {
        id: tb
        property string icon: ""
        property string text: ""
        property bool filled: false
        property bool tonal: false
        property bool danger: false
        signal clicked()
        height: Tokens.islandHeight * 1.15
        width: tbRow.implicitWidth + Tokens.padding * 2
        radius: height / 2
        color: filled ? Colors.accent
             : danger ? (tbMouse.containsMouse ? Colors.alpha(Colors.danger, 0.28) : Colors.alpha(Colors.danger, 0.16))
             : tonal ? (tbMouse.containsMouse ? Colors.alpha(Colors.accent, 0.3) : Colors.alpha(Colors.accent, Colors.dark ? 0.2 : 0.14))
             : "transparent"
        scale: tbMouse.pressed ? 0.95 : 1
        Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
        Row {
            id: tbRow
            anchors.centerIn: parent
            spacing: 6
            Icon { visible: tb.icon !== ""; name: tb.icon; size: Tokens.textSize + 2; color: tb.filled ? Colors.onAccent : tb.danger ? Colors.danger : Colors.text; anchors.verticalCenter: parent.verticalCenter }
            Label { text: tb.text; font.weight: Font.Medium; role: tb.filled ? "onAccent" : tb.danger ? "danger" : "text"; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: tbMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tb.clicked() }
    }
}
