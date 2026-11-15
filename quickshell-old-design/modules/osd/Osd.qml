import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Volume indicator bottom center, fades out after a short time. Clicks go through.
PanelWindow {
    id: win

    property bool shown: false
    property bool mapped: false
    readonly property real t: box.t

    screen: Ui.focusedScreen()
    visible: win.mapped
    color: "transparent"
    implicitWidth: 300
    implicitHeight: 64
    exclusionMode: ExclusionMode.Ignore

    anchors.bottom: true
    margins.bottom: 90

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-osd"

    mask: Region {}

    Connections {
        target: Audio

        function onOsdRequested() {
            if (!Config.opts.osdEnabled)
                return;
            unmapHold.stop();
            win.mapped = true;
            win.shown = true;
            hideTimer.restart();
        }
    }

    // Only close the window after fading out + one empty frame
    Timer {
        id: unmapHold

        interval: Math.round(Theme.durMed * Config.opts.animOsdSpeed) + 80
        onTriggered: {
            if (!win.shown)
                win.mapped = false;
        }
    }

    Timer {
        id: hideTimer

        interval: 1400
        onTriggered: {
            win.shown = false;
            unmapHold.restart();
        }
    }

    Rectangle {
        id: box

        property real t: win.shown ? 1 : 0

        anchors.horizontalCenter: parent.horizontalCenter
        // Glides subpixel like the bar: as a texture while moving (text sharp), on whole pixels at rest
        y: 8 + 12 * (1 - t)
        width: parent.width
        height: 48
        radius: height / 2
        color: Glass.popupBg
        border.width: 1
        border.color: Theme.borderStrong
        opacity: t
        layer.enabled: t > 0 && t < 1
        layer.smooth: true

        Behavior on t {
            Anim {
                duration: Math.round(Theme.durMed * Config.opts.animOsdSpeed)
                easing.bezierCurve: Theme.curveSmooth
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 14

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                text: Audio.icon()
            }

            Meter {
                anchors.verticalCenter: parent.verticalCenter
                width: 180
                height: 6
                value: Audio.muted ? 0 : Audio.volume
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                horizontalAlignment: Text.AlignRight
                text: Audio.muted ? "–" : Math.round(Audio.volume * 100)
                font.weight: Theme.weightStrong
            }
        }
    }
}
