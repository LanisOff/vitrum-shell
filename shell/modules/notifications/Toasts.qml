import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme
import qs.components
import "../../lib/bar.js" as BarLib

/*
 * Toast stack in a corner (notifications.position), on the focused screen
 * (or the primary one, per notifications.screen). Newest on top, one card
 * per app with a count of the rest.
 */
PanelWindow {
    id: root
    required property var modelData
    screen: modelData

    readonly property string where: Settings.get("notifications.position", "top-right")
    readonly property string target: Settings.get("notifications.screen", "focused") === "primary"
        ? BarLib.primaryScreen(Quickshell.screens, Settings.get("bar.primary", ""))
        : (Niri.focusedOutput || Quickshell.screens[0].name)
    // The centre shows them all; toasts would cover it.
    readonly property bool active: screen.name === target && stack.count > 0 && !UiState.centre

    // One card per app: the newest, with how many are behind it.
    readonly property var cards: {
        const seen = {}, out = [];
        for (const n of Notifs.popups) {
            if (seen[n.appName] !== undefined) { out[seen[n.appName]].count++; continue; }
            seen[n.appName] = out.length;
            out.push({ key: n.appName, item: n, count: 1 });
        }
        return out.slice(0, 5);
    }
    function cardFor(key) { return cards.find(c => c.key === key) || null; }

    visible: true
    anchors { top: where.indexOf("top") === 0; bottom: where.indexOf("bottom") === 0; right: where.endsWith("right"); left: where.endsWith("left") }
    margins { top: Tokens.islandHeight + 2 * Tokens.gap; bottom: Tokens.gap; right: Tokens.gap; left: Tokens.gap }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: Tokens.islandHeight * 12 + Tokens.gap
    implicitHeight: Math.max(1, stack.implicitHeight)
    color: "transparent"
    WlrLayershell.namespace: "vitrum-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    // A click on a reply field takes the keyboard; nothing else ever does.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    mask: Region { item: root.active ? stack : dot }
    BlurKick { id: blurKick; window: root }
    BackgroundEffect.blurRegion: Materials.wantsRegion("notifications") && !blurKick.on ? effect : blurKick.none
    Region { id: effect; regions: root.active ? stack.regions : [dotRegion] }
    Region { id: dotRegion; item: dot }
    Item { id: dot; width: 1; height: 1 }

    // A ListView, not a Repeater: delegates are kept by app (ScriptModel keyed
    // on it), so a dismissed toast leaves on its own and the rest close the gap
    // — a Repeater over a fresh array re-created (and re-slid) every card.
    ListView {
        id: stack
        width: parent.width
        height: contentHeight
        implicitHeight: contentHeight
        interactive: false
        spacing: Tokens.gap
        property list<Region> regions: []
        function collect() { const r = []; for (let i = 0; i < count; i++) { const t = itemAtIndex(i); if (t) r.push(t.region); } regions = r; }
        visible: root.active
        model: ScriptModel { values: root.cards.map(c => ({ key: c.key })); objectProp: "key" }
        delegate: Item {
            id: slot
            required property var modelData
            // The last card seen: while it slides out the toast is no longer in popups.
            readonly property var live: root.cardFor(modelData.key)
            property var card: null
            onLiveChanged: if (live) card = live
            Component.onCompleted: { card = live; Qt.callLater(stack.collect); }
            readonly property Region region: toast.region
            width: toast.width
            height: toast.implicitHeight
            Toast {
                id: toast
                item: slot.card ? slot.card.item : ({})
                count: slot.card ? slot.card.count : 1
                height: implicitHeight
            }
            Component.onDestruction: Qt.callLater(stack.collect)
        }
        add: Transition { enabled: Motion.enabled; NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.fast } }
        remove: Transition {
            enabled: Motion.enabled
            NumberAnimation { property: "x"; to: Tokens.islandHeight * 4; duration: Motion.standard; easing.type: Easing.InCubic }
            NumberAnimation { property: "opacity"; to: 0; duration: Motion.standard; easing.type: Easing.InCubic }
        }
        displaced: Transition { enabled: Motion.enabled; NumberAnimation { property: "y"; duration: Motion.standard; easing.type: Easing.OutCubic } }
    }
}
