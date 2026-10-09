//@ pragma AppId vitrum-about
//@ pragma Env VITRUM_NO_THEME=1
//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components
import qs.common

/*
 * About this computer: what it is and what it runs. Everything comes from the
 * SysInfo service (the shell's), the vitrum version from the installer.
 * Unknown values say so instead of failing.
 */
ShellRoot {
    id: app
    property string version: ""
    FileView {
        path: Quickshell.env("HOME") + "/.local/share/vitrum/version"
        onLoaded: app.version = text().trim()
        onLoadFailed: app.version = ""
    }
    Component.onCompleted: SysInfo.refreshDisplays()
    readonly property var rows: [
        { k: "System",     v: SysInfo.distro },
        { k: "Kernel",     v: SysInfo.kernel ? SysInfo.kernel + (SysInfo.arch ? " · " + SysInfo.arch : "") : "" },
        { k: "Processor",  v: SysInfo.cpuModel ? SysInfo.cpuModel + (SysInfo.cpuThreads ? " · " + SysInfo.cpuCores + " cores, " + SysInfo.cpuThreads + " threads" : "") : "" },
        { k: "Graphics",   v: SysInfo.gpuModel },
        { k: "Memory",     v: SysInfo.memoryTotalGB ? SysInfo.memoryTotalGB.toFixed(0) + " GB" + (SysInfo.memoryDetail ? " · " + SysInfo.memoryDetail : "") : "" },
        { k: "Display",    v: SysInfo.primaryDisplay },
        { k: "Board",      v: SysInfo.modelLine + (SysInfo.biosVersion ? " · firmware " + SysInfo.biosVersion : "") },
        { k: "Up",         v: SysInfo.uptime },
        { k: "Packages",   v: SysInfo.packageCount ? String(SysInfo.packageCount) : "" },
        { k: "Compositor", v: SysInfo.niriVersion ? "niri " + SysInfo.niriVersion : "" },
        { k: "vitrum",     v: app.version }
    ]
    function report() {
        return [SysInfo.hostname].concat(rows.map(r => r.k + ": " + (r.v || "unknown"))).join("\n");
    }

    AppWindow {
        appTitle: "About this computer"
        implicitWidth: 720
        implicitHeight: 600

        Flickable {
            id: flick
            anchors.fill: parent
            contentHeight: col.implicitHeight + Tokens.padding * 3
            clip: true
            Column {
                id: col
                x: Tokens.padding * 2; y: Tokens.padding
                width: flick.width - Tokens.padding * 4
                spacing: Tokens.gap * 2

                Row {
                    spacing: Tokens.padding * 1.5
                    Rectangle {
                        id: badge
                        width: 96; height: 96; radius: 28
                        // Pops in when the window opens.
                        scale: Motion.enabled ? 0.4 : 1
                        opacity: Motion.enabled ? 0 : 1
                        Component.onCompleted: if (Motion.enabled) badgeIn.start()
                        ParallelAnimation {
                            id: badgeIn
                            NumberAnimation { target: badge; property: "scale"; to: 1; duration: Motion.emphasized * 1.3; easing.type: Easing.OutBack; easing.overshoot: 2.6 }
                            NumberAnimation { target: badge; property: "opacity"; to: 1; duration: Motion.standard; easing.type: Easing.OutCubic }
                        }
                        gradient: Gradient {
                            GradientStop { position: 0; color: Colors.accent }
                            GradientStop { position: 1; color: Qt.darker(Colors.accent, 1.6) }
                        }
                        Icon { anchors.centerIn: parent; name: "screen"; size: 52; color: Colors.onAccent; filled: true }
                    }
                    Column {
                        id: names
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        // Slides in beside the badge.
                        transform: Translate { id: namesShift; x: Motion.enabled ? 32 : 0 }
                        opacity: Motion.enabled ? 0 : 1
                        Component.onCompleted: if (Motion.enabled) namesIn.start()
                        SequentialAnimation {
                            id: namesIn
                            PauseAnimation { duration: 80 }
                            ParallelAnimation {
                                NumberAnimation { target: namesShift; property: "x"; to: 0; duration: Motion.emphasized; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
                                NumberAnimation { target: names; property: "opacity"; to: 1; duration: Motion.standard; easing.type: Easing.OutCubic }
                            }
                        }
                        Label { text: SysInfo.hostname || "This computer"; size: Tokens.textTitle * 1.6; font.weight: Font.DemiBold }
                        Label { text: SysInfo.modelLine; role: "dim" }
                        Label { text: (SysInfo.userRealName || SysInfo.userName) ? "Signed in as " + (SysInfo.userRealName || SysInfo.userName) : ""; role: "dim"; size: Tokens.textSmall; visible: text.length > 0 }
                    }
                }

                Section {
                    Repeater {
                        model: app.rows
                        delegate: SettingRow {
                            id: infoRow
                            required property var modelData
                            required property int index
                            // One after another, rising into the card.
                            transform: Translate { id: rowShift; y: Motion.enabled ? 14 : 0 }
                            opacity: Motion.enabled ? 0 : 1
                            Component.onCompleted: if (Motion.enabled) rowIn.start()
                            SequentialAnimation {
                                id: rowIn
                                PauseAnimation { duration: 140 + infoRow.index * 35 }
                                ParallelAnimation {
                                    NumberAnimation { target: rowShift; property: "y"; to: 0; duration: Motion.emphasized; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                                    NumberAnimation { target: infoRow; property: "opacity"; to: 1; duration: Motion.standard; easing.type: Easing.OutCubic }
                                }
                            }
                            label: modelData.k
                            divider: index < app.rows.length - 1
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, col.width * 0.62)
                                horizontalAlignment: Text.AlignRight
                                text: modelData.v || "Unknown"
                                role: modelData.v ? "text" : "dim"
                            }
                        }
                    }
                }

                Row {
                    spacing: Tokens.gap
                    Rectangle {
                        height: Tokens.islandHeight * 1.2; radius: height / 2; width: cl.implicitWidth + Tokens.padding * 2
                        Behavior on width { enabled: Motion.enabled; SpringAnim { token: Motion.bouncy } }
                        color: Colors.accent
                        scale: cm.pressed ? 0.93 : 1
                        Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.bouncy } }
                        Label {
                            id: cl; anchors.centerIn: parent; text: copied.running ? "Copied" : "Copy details"; role: "onAccent"; font.weight: Font.DemiBold
                            // The new word pops up in place of the old one.
                            onTextChanged: if (Motion.enabled) { cl.scale = 0.6; cl.opacity = 0; wordIn.restart(); }
                            ParallelAnimation {
                                id: wordIn
                                NumberAnimation { target: cl; property: "scale"; to: 1; duration: Motion.standard; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
                                NumberAnimation { target: cl; property: "opacity"; to: 1; duration: Motion.fast; easing.type: Easing.OutCubic }
                            }
                        }
                        MouseArea { id: cm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Quickshell.execDetached(["wl-copy", "--", app.report()]); copied.restart(); } }
                    }
                    Rectangle {
                        height: Tokens.islandHeight * 1.2; radius: height / 2; width: sl.implicitWidth + Tokens.padding * 2
                        color: sm.containsMouse ? Colors.alpha(Colors.text, 0.12) : Colors.alpha(Colors.text, 0.06)
                        Behavior on color { enabled: Motion.enabled; ColorAnim { duration: Motion.fast } }
                        scale: sm.pressed ? 0.93 : 1
                        Behavior on scale { enabled: Motion.enabled; SpringAnim { token: Motion.bouncy } }
                        Label { id: sl; anchors.centerIn: parent; text: "Settings" }
                        MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["vitrum-settings"]) }
                    }
                    Timer { id: copied; interval: 1500 }
                }
            }
        }
    }
}
