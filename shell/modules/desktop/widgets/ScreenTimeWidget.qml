import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components
import "../../../lib/screentime.js" as Lib

/*
 * Screen time today: how long each app has had the focus (ScreenTime, which
 * counts only while this widget is on the desktop, and not while locked or
 * away).
 *   M   the header, today's total at its end; the most used apps, a row
 *       each — the icon, the name, a lit bar against the first, the time
 *   L   the total large under the header; more rows
 * options: count (how many apps at most).
 * In a gallery card, a sample day.
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    signal optionsEdited(var options)

    readonly property bool large: sizeClass === "L" || sizeClass === "XL"
    readonly property int count: Math.max(1, Number(options.count) || 5)

    readonly property var sampleDay: ({ "firefox": 7420, "kitty": 4380, "code": 3310, "org.telegram.desktop": 1260, "vesktop": 840, "mpv": 600 })
    readonly property var day: preview ? sampleDay : ScreenTime.today
    readonly property real total: Lib.total(day)
    readonly property var apps: Lib.ranked(day, count).map(r => {
        const a = Apps.forAppId(r.app);
        return { id: r.app, seconds: r.seconds, name: a ? a.name : r.app, icon: a ? a.icon : "" };
    })
    readonly property real most: apps.length ? apps[0].seconds : 1

    WidgetHeader {
        id: head
        icon: "hourglass"; title: "Screen time"
        trailing: root.large || root.apps.length === 0 ? "Today" : Lib.duration(root.total)
    }
    WidgetEmpty {
        visible: root.apps.length === 0
        icon: "hourglass"
        text: ScreenTime.on || root.preview ? "Counting from now: switch to an app" : "Counting starts once the widget is saved"
    }

    // ---- L: today's total, large.
    Row {
        id: big
        visible: root.large && root.apps.length > 0
        anchors { left: parent.left; top: head.bottom; topMargin: Tokens.gap * 0.4 }
        height: visible ? implicitHeight : 0
        spacing: Tokens.gap * 0.6
        readonly property int mins: Math.floor(root.total / 60)
        Metric {
            visible: big.mins >= 60
            value: String(Math.floor(big.mins / 60)); unit: "h"
            size: Math.round(Tokens.textTitle * 1.5)
        }
        Metric {
            value: big.mins < 1 ? "<1" : String(big.mins >= 60 ? big.mins % 60 : big.mins); unit: "min"
            size: Math.round(Tokens.textTitle * 1.5)
        }
    }

    Column {
        id: rows
        visible: root.apps.length > 0
        anchors { left: parent.left; right: parent.right; top: big.visible ? big.bottom : head.bottom; topMargin: Tokens.gap * (big.visible ? 0.6 : 0.5); bottom: parent.bottom }
        readonly property real rowH: Math.round(Tokens.textSize * 1.95)
        readonly property int fits: Math.max(1, Math.floor((height + spacing) / (rowH + spacing)))
        spacing: Math.round(Tokens.gap * 0.2)
        Repeater {
            model: root.apps.slice(0, rows.fits)
            delegate: Item {
                id: row
                required property var modelData
                width: rows.width; height: rows.rowH
                Item {
                    id: lead
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(Tokens.textSize * 1.45); height: width
                    IconImage {
                        id: img
                        anchors.centerIn: parent
                        implicitSize: parent.width
                        source: row.modelData.icon ? Apps.iconSource(row.modelData.icon) : ""
                    }
                    // No app or no icon: the line glyph, never the missing texture.
                    Icon { anchors.centerIn: parent; visible: img.source == ""; name: "window"; size: Math.round(parent.width * 0.8); color: Colors.textDim }
                }
                Label {
                    id: name
                    anchors { left: lead.right; leftMargin: Tokens.gap * 0.7; verticalCenter: parent.verticalCenter }
                    width: Math.round(rows.width * 0.34)
                    text: row.modelData.name
                    font.weight: Font.Medium
                    size: Tokens.textSmall + 1
                }
                Meter {
                    group: "widgets"
                    anchors { left: name.right; leftMargin: Tokens.gap * 0.6; right: time.left; rightMargin: Tokens.gap * 0.8; verticalCenter: parent.verticalCenter }
                    thickness: 5
                    value: row.modelData.seconds / root.most
                }
                Label {
                    id: time
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: Math.round(Tokens.textSmall * 4.2)
                    horizontalAlignment: Text.AlignRight
                    text: Lib.duration(row.modelData.seconds, true)
                    numeric: true; size: Tokens.textSmall; font.weight: Font.Medium
                }
            }
        }
    }
}
