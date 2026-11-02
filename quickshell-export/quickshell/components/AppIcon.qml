import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.config

// App-/Tray-Icon. Optional schwarz-weiss. Faellt auf einen Buchstaben zurueck.
Item {
    id: root

    property string icon: ""
    property string source: ""
    property string fallback: "?"
    property bool monochrome: Config.opts.monochromeIcons

    readonly property string resolved: {
        if (root.source !== "")
            return root.source;
        if (root.icon === "")
            return "";
        if (root.icon.startsWith("/"))
            return "file://" + root.icon;
        if (root.icon.startsWith("file://") || root.icon.startsWith("image://"))
            return root.icon;
        return Quickshell.iconPath(root.icon, true);
    }

    implicitWidth: 32
    implicitHeight: 32

    IconImage {
        id: img

        anchors.fill: parent
        visible: root.resolved !== "" && status !== Image.Error
        source: root.resolved
        asynchronous: true
        layer.enabled: root.monochrome
        layer.effect: MultiEffect {
            saturation: -1.0
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: !img.visible
        radius: Theme.radiusSm
        color: Theme.layer3

        Txt {
            anchors.centerIn: parent
            text: root.fallback.length > 0 ? root.fallback.charAt(0).toUpperCase() : "?"
            font.pixelSize: Math.max(8, Math.round(root.height * 0.45))
            font.weight: Theme.weightStrong
            color: Theme.fgDim
        }
    }
}
