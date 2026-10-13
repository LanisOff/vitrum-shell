import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.components

/*
 * A widget of your own: ~/.config/vitrum/widgets/<folder>/Widget.qml (with a
 * manifest.json, CustomWidgets). It gets the same contract as the built-in
 * ones and can import qs.components, qs.theme and qs.services. Saving the file
 * reloads it here (the URL carries a counter, so the engine does not hand back
 * the cached component).
 */
Item {
    id: root
    property var options: ({})
    property string sizeClass: "M"
    property bool preview: false
    property string type: ""
    signal optionsEdited(var options)

    readonly property string folder: type.indexOf("qml:") === 0 ? type.slice(4) : ""
    // Built from folder in each binding: one reading a separate `path` could
    // see it a step behind, still the empty folder's ("widgets//Widget.qml").
    function fileOf(f) { return CustomWidgets.dir + "/" + f + "/Widget.qml"; }
    property int stamp: 0
    FileView {
        path: root.folder ? root.fileOf(root.folder) : ""
        watchChanges: true
        printErrors: false
        onFileChanged: { root.stamp++; reload(); }
    }
    Loader {
        id: loader
        anchors.fill: parent
        source: root.folder ? "file://" + root.fileOf(root.folder) + "?v=" + root.stamp : ""
        onLoaded: {
            if (item.hasOwnProperty("options")) item.options = Qt.binding(() => root.options);
            if (item.hasOwnProperty("sizeClass")) item.sizeClass = Qt.binding(() => root.sizeClass);
            if (item.hasOwnProperty("preview")) item.preview = Qt.binding(() => root.preview);
            if (item.optionsEdited) item.optionsEdited.connect(o => root.optionsEdited(o));
        }
    }
    WidgetEmpty {
        visible: loader.status === Loader.Error || !root.folder
        icon: "code"
        text: root.folder + "/Widget.qml did not load — the shell log says why"
    }
}
