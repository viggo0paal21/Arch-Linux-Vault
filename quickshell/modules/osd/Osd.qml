import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Lautstaerke-Anzeige unten mittig, blendet nach kurzer Zeit aus. Klicks gehen durch.
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

    // Fenster erst nach dem Ausblenden + einem leeren Frame schliessen
    Timer {
        id: unmapHold

        interval: Theme.durMed + 80
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
        y: Math.round(8 + 12 * (1 - t))
        width: parent.width
        height: 48
        radius: height / 2
        color: Theme.bg
        border.width: 1
        border.color: Theme.borderStrong
        opacity: t

        Behavior on t {
            Anim {
                duration: Theme.durMed
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
