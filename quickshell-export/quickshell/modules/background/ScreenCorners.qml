import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// Vier kleine schwarze Ecken pro Bildschirm. Ebene "Top": Vollbild-Spiele liegen darueber,
// es gibt also keine Ueberlagerung im Spiel (Direct Scanout bleibt moeglich).
Scope {
    id: root

    required property var modelData
    readonly property int size: Math.max(6, Theme.radiusLg)

    component Corner: PanelWindow {
        id: corner

        property int rot: 0
        property int cornerSize: 12

        color: "transparent"
        implicitWidth: corner.cornerSize
        implicitHeight: corner.cornerSize
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-corner"

        Canvas {
            anchors.fill: parent
            rotation: corner.rot
            onWidthChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                const r = width;
                ctx.reset();
                ctx.fillStyle = "#000000";
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.lineTo(r, 0);
                ctx.arc(r, r, r, -Math.PI / 2, Math.PI, true);
                ctx.closePath();
                ctx.fill();
            }
        }
    }

    Corner {
        rot: 0
        screen: root.modelData
        cornerSize: root.size
        anchors.top: true
        anchors.left: true
    }

    Corner {
        rot: 90
        screen: root.modelData
        cornerSize: root.size
        anchors.top: true
        anchors.right: true
    }

    Corner {
        rot: 180
        screen: root.modelData
        cornerSize: root.size
        anchors.bottom: true
        anchors.right: true
    }

    Corner {
        rot: 270
        screen: root.modelData
        cornerSize: root.size
        anchors.bottom: true
        anchors.left: true
    }
}
