import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// Background per screen: true black or an image.
PanelWindow {
    id: win

    required property var modelData
    readonly property string path: {
        const p = Config.opts.wallpaper.trim();
        if (p === "")
            return "";
        const home = Quickshell.env("HOME") || "";
        const abs = p.startsWith("~") ? home + p.slice(1) : p;
        return abs.startsWith("file://") ? abs : "file://" + abs;
    }

    screen: modelData
    color: Theme.bg
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "qs-wallpaper"

    Image {
        anchors.fill: parent
        visible: win.path !== "" && status === Image.Ready
        source: win.path
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: win.width
        sourceSize.height: win.height
    }
}
